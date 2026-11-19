# QOL Logistics

A Factorio 2.1 mod for the base game and Space Age. Put the ZIP, still zipped,
in your Factorio mods folder, start Factorio, and enable QOL Logistics.

## Craft and place a loader

Every generated recipe makes one loader from one transport belt, one matching
underground belt, and basic inserters. Divide the belt speed by the
starting yellow belt speed and round up to get the inserter count. In the
base game and Space Age this gives yellow 1, red 2, blue 3, and green 4.
If the standard yellow belt is absent, the baseline is 15 items/s.
Recipes normally unlock with the
matching underground belt's research. Yellow loaders use yellow belts, red
loaders use red belts, and so on. Each loader moves items at the speed of its
transport belt across both lanes.

Put a loader on the tile between a belt and a chest or crafting machine. Point
the belt side toward the belt. Rotate the placed loader with R to switch the
flow between the building and the belt. For machines, set the recipe so the
loader knows which ingredients the machine can accept.

## Modded belts

The mod reads standard transport belt and underground belt prototypes during
Factorio's final data stage. It matches speed and uses names, crafting
ingredients, and item subgroups to distinguish belts that share a speed. Belts
without a craftable loader pair, including pairs with no matching underground
belt or a tied best match, are reported in factorio-current.log. Belts created
later in another mod's final data stage may need explicit load ordering.

The loaders use Factorio's built-in single-tile loader entity with original
industrial housing artwork inspired by AAI Loaders.
They operate without electricity or lubricant. They are designed for
stationary machines and chests.

## Train Loader

Craft one Train Loader from six matching Adaptive Belt Loaders. The platform
is six tiles along a straight ground rail and two tiles deep. Rotate it before
placing so its steel hoods face the rail. Center it on a stopped cargo wagon
and connect up to six belts to the opposite edge.

Click the platform to open its internal buffer. It holds 40 slots at normal
quality, 52 at uncommon, 64 at rare, 76 at epic, and 100 at legendary.
Connect a red or green circuit wire directly to the platform to read its
current buffer contents.

Hover over the platform and press Shift + L to switch between loading and
unloading. In loading mode, point the feed belts toward the platform. Items
pass through the buffer in either mode. Mine the platform to remove all six
outlets together.

## Shipping Packer
The Shipping Packer has three slots for Speed Modules.
Packing and unpacking each take five seconds per container at base crafting speed.

Research Automation 2, then craft and power the 4×6 Shipping Packer.
Choose a recipe on the Packing tab and supply one full stack of the selected item and one
Empty Shipping Container. Packed containers stack to 50, and one full stack fills a standard rocket. Use the corresponding recipe on the Unpacking tab at the destination to
recover the full stack and the empty container.

Recipes support ordinary stackable, non-spoiling items. Select the desired
quality in the recipe picker and use cargo and empty containers of that quality.

## Gravel Path

Hold ordinary stone and place it on land like stone paving to make a Gravel
Path, using one stone per tile. No crafting or research is needed. Walk on it
at 120% of normal speed (20% faster), and mine it to recover stone. It uses
gray-tinted base-game stone-path graphics.

## License

The QOL Logistics source code and accompanying documentation are available
under the MIT License. See [LICENSE](LICENSE). The grant covers the code
and documentation. Artwork and Factorio assets referenced by the mod are
outside this grant.
