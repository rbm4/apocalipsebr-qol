require "Definitions/ContainerButtonIcons"

ContainerButtonIcons = ContainerButtonIcons or {}

local textureButtonIcons = {}

textureButtonIcons.container_ghostbusters = getTexture("media/ui/container_ghostbusters.png")
textureButtonIcons.container_ravenclock = getTexture("media/ui/container_ravenclock.png")
textureButtonIcons.container_ataud = getTexture("media/ui/container_ataud.png")

ContainerButtonIcons.ghostcontainer = textureButtonIcons.container_ghostbusters
ContainerButtonIcons.ravenclockcontainer = textureButtonIcons.container_ravenclock
ContainerButtonIcons.ataudcontainer = textureButtonIcons.container_ataud