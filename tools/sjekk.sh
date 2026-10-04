#!/bin/sh
# Sjekker all Luau-koden med luau-analyze (brew install luau). Skriver bare ekte funn.
# Bruk: tools/sjekk.sh            (alle filer i src/)
cd "$(dirname "$0")/.." || exit 1
FILER=$(find src -name '*.lua' -o -name '*.luau' | sort)
UT=$(luau-analyze --formatter=plain $FILER 2>&1 \
	| grep -v -E "\(W0\) (LocalShadow)|UnknownType: Unknown type '(Instance|Vector3|CFrame|Color3|EnumItem|Vector2)'" \
	| grep -v -E "Unknown require: unsupported path" )
if [ -z "$UT" ]; then
	echo "Luau-sjekk: ingen feil i $(echo "$FILER" | wc -l | tr -d ' ') filer."
	exit 0
fi
echo "$UT"
exit 1
