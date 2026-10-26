-- Icones de l'interface (ReplicatedStorage.Shared.Icons)
-- Images generees par tools/icones/generer_icones.py (assets/icones) puis envoyees sur Roblox.
-- Ids : identifiant Roblox de chaque image. Tant qu'il est vide, l'interface affiche une
-- pastille de couleur a la place.
local Icons = {}

Icons.Ids = {
	Or = "rbxassetid://113978451862074",
	Neant = "rbxassetid://120063103189569",
	Seve = "rbxassetid://85628673656371",
	Braise = "rbxassetid://136133327633344",
	Givre = "rbxassetid://137450233198937",
	Solaire = "rbxassetid://77888361396236",
	Cle = "rbxassetid://91316154459956",
	Oeuf = "rbxassetid://87990546412278",
	OeufMythique = "rbxassetid://122890557098601",
	Familiers = "rbxassetid://116921084775930",
	Teleport = "rbxassetid://108638130118312",
	Tour = "rbxassetid://83971190273699",
	Cadeau = "rbxassetid://111762718151679",
	Boutique = "rbxassetid://121449134107302",
	Puissance = "rbxassetid://100802403855596",
	Bouclier = "rbxassetid://76377007822115",
	Verrou = "rbxassetid://73407074735388",
	Epee = "rbxassetid://121033209683534",
	Coffre = "rbxassetid://100271809893595",
	Trophee = "rbxassetid://126978690844153",
	Etoile = "rbxassetid://132111362635420",
	Couronne = "rbxassetid://102662417902335",
	Auto = "rbxassetid://74907631861130",
	Fermer = "rbxassetid://113736838311317",
	Valider = "rbxassetid://94541979281296",
	Plus = "rbxassetid://73961126483590",
	Ameliorer = "rbxassetid://116253303286491",
	Vie = "rbxassetid://134184948343984",
	Quete = "rbxassetid://111223221913508",
	Horloge = "rbxassetid://112974955728183",
	Fusion = "rbxassetid://70759460702840",
	Butin = "rbxassetid://134554524446491",
	Donjon = "rbxassetid://91632153569088",
	Boost = "rbxassetid://91180524038540",
	Rayons = "rbxassetid://93290692182131",
	Logo = "rbxassetid://73787262667668",
	Musique = "rbxassetid://92320010021707",
}

-- Couleur de la pastille de remplacement
Icons.Colors = {
	Or = Color3.fromRGB(255, 205, 60),
	Neant = Color3.fromRGB(165, 95, 255),
	Seve = Color3.fromRGB(80, 220, 120),
	Braise = Color3.fromRGB(255, 90, 60),
	Givre = Color3.fromRGB(90, 200, 255),
	Solaire = Color3.fromRGB(255, 205, 70),
	Familiers = Color3.fromRGB(255, 140, 185),
	Teleport = Color3.fromRGB(150, 110, 255),
	Tour = Color3.fromRGB(190, 175, 225),
	Cadeau = Color3.fromRGB(255, 90, 120),
	Boutique = Color3.fromRGB(255, 160, 50),
	Puissance = Color3.fromRGB(255, 220, 60),
	Bouclier = Color3.fromRGB(80, 160, 250),
	Vie = Color3.fromRGB(240, 70, 90),
	Valider = Color3.fromRGB(70, 210, 100),
	Fermer = Color3.fromRGB(240, 240, 250),
}

function Icons.get(name: string): string?
	local id = Icons.Ids[name]
	return if id and id ~= "" then id else nil
end

return Icons
