#!/usr/bin/env python3
"""
Kjører en Luau-test mot spillets moduler med `luau` på Macen (brew install luau).

    python3 tools/test_luau.py test/bane.test.lua            -> kjører testen
    python3 tools/test_luau.py test/bane.test.lua --data x.json  -> lagrer linjer som starter med DATA:

Rene moduler (uten Instance, workspace osv.) kan lastes: testen kaller krev("shared/Bane").
`script.Parent.X` og `game:GetService("ReplicatedStorage").Shared.X` i modulene virker.
Roblox-typene Vector3, CFrame, Random, Color3 og Enum finnes som enkle erstatninger (test/shims.lua).
"""
import json
import os
import subprocess
import sys
import tempfile

ROT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
MAPPER = {'shared': 'src/shared', 'server': 'src/server', 'client': 'src/client'}


def moduler():
    """Alle .lua-filer. Skript (Main.server.lua, Klient.client.lua) får nøkkel uten .server/.client."""
    ut = {}
    for nokkel, mappe in MAPPER.items():
        full = os.path.join(ROT, mappe)
        for fil in sorted(os.listdir(full)):
            if fil.endswith('.lua'):
                navn = fil[:-4]
                for ende in ('.server', '.client'):
                    if navn.endswith(ende):
                        navn = navn[:-len(ende)]
                with open(os.path.join(full, fil), encoding='utf-8') as fh:
                    ut[f'{nokkel}/{navn}'] = fh.read()
    return ut


RAMME = r'''
local MODULER = {}
local LASTET = {}
local function lagMappe(sti)
	return setmetatable({ __sti = sti }, { __index = function(t, navn)
		if navn == "WaitForChild" or navn == "FindFirstChild" then
			return function(selv, barn)
				return lagMappe(sti == "" and barn or (sti .. "/" .. barn))
			end
		end
		if navn == "Parent" then
			local forelder = string.match(sti, "^(.*)/[^/]+$")
			return lagMappe(forelder or "")
		end
		return lagMappe(sti == "" and navn or (sti .. "/" .. navn))
	end })
end
function krev(mal)
	local sti = type(mal) == "string" and mal or rawget(mal, "__sti")
	if LASTET[sti] ~= nil then
		return LASTET[sti]
	end
	local f = MODULER[sti]
	if not f then
		error("Fant ikke modulen " .. tostring(sti))
	end
	local verdi = f(lagMappe(sti), function(m) return krev(m) end)
	LASTET[sti] = verdi
	return verdi
end
local REPLIKERT = lagMappe("shared")
game = { GetService = function(_, navn)
	if navn == "ReplicatedStorage" then
		local rs
		rs = setmetatable({}, { __index = function(_, k)
			if k == "WaitForChild" or k == "FindFirstChild" then
				return function(_, n) return rs[n] end
			end
			if k == "Shared" then return REPLIKERT end
			error("ReplicatedStorage." .. k .. " finnes ikke i testen")
		end })
		return rs
	end
	error("Tjenesten " .. navn .. " finnes ikke i testen")
end }
'''


MOCK_RAMME = r'''
-- I mock-modus speiles prosjektet som instanser (ReplicatedStorage.Shared, ServerScriptService.Server ...)
local SKRIPT = {}
local PLASS = { shared = { "ReplicatedStorage", "Shared" }, server = { "ServerScriptService", "Server" },
	client = { "StarterPlayer", "Klient" } }
for sti in MODULER do
	local mappeNavn, navn = string.match(sti, "^(%w+)/(.+)$")
	local plass = PLASS[mappeNavn]
	local tj = game:GetService(plass[1])
	local mappe = tj:FindFirstChild(plass[2])
	if not mappe then
		mappe = Instance.new("Folder")
		mappe.Name = plass[2]
		mappe.Parent = tj
	end
	local ms = Instance.new("ModuleScript")
	ms.Name = navn
	ms:SetAttribute("__sti", sti)
	ms.Parent = mappe
	SKRIPT[sti] = ms
end
krev = function(mal)
	local sti = type(mal) == "string" and mal or mal:GetAttribute("__sti")
	if LASTET[sti] ~= nil then
		return LASTET[sti]
	end
	local f = MODULER[sti]
	if not f then
		error("Fant ikke modulen " .. tostring(sti))
	end
	local verdi = f(SKRIPT[sti], krev)
	LASTET[sti] = verdi
	return verdi
end
'''


def bygg(testfil, mock=False):
    deler = [open(os.path.join(ROT, 'test', 'shims.lua'), encoding='utf-8').read(), RAMME]
    if mock:
        deler.append(open(os.path.join(ROT, 'test', 'roblox_mock.lua'), encoding='utf-8').read())
    for navn, kilde in moduler().items():
        deler.append(f'MODULER[{json.dumps(navn)}] = function(script, require)\n{kilde}\nend\n')
    if mock:
        deler.append(MOCK_RAMME)
    with open(testfil, encoding='utf-8') as fh:
        deler.append('do\n' + fh.read() + '\nend\n')
    return '\n'.join(deler)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    testfil = sys.argv[1]
    data_ut = sys.argv[sys.argv.index('--data') + 1] if '--data' in sys.argv else None
    kode = bygg(testfil, mock='--mock' in sys.argv)
    with tempfile.NamedTemporaryFile('w', suffix='.luau', delete=False, encoding='utf-8') as tmp:
        tmp.write(kode)
        sti = tmp.name
    res = subprocess.run(['luau', sti], capture_output=True, text=True)
    data = []
    for linje in res.stdout.splitlines():
        if linje.startswith('DATA:'):
            data.append(json.loads(linje[5:]))
        else:
            print(linje)
    if res.stderr.strip():
        print(res.stderr.strip())
        # vis linjenummer i den samlede fila for feilsøking
        print(f'(samlet testfil: {sti})')
    if data_ut:
        with open(data_ut, 'w') as fh:
            json.dump(data, fh)
        print(f'Lagret {len(data)} DATA-linjer i {data_ut}')
    sys.exit(res.returncode)


if __name__ == '__main__':
    main()
