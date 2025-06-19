<# 
Make Junk Files
Originally from: https://github.com/cosmickatamari/Bulk-File-Organization/tree/main
Last Updated: 6/19/2025 by Cosmic Katamari

-----

This is a pretty standard script that will read from the below arrays for file names, and generate a predefined amount of junk files (amount can be changed at the bottom). 
The time stamp was included in the random file because in testing, having files with zero bytes caused issues trying to delete them in File Explorer. Oddly enough, once the files had some data in them, it was faster to delete the same amount of files from the same location.

If you make any changes to the array names, make sure to change the reference in $wordlist so that it's included.
It's currently set to make 5,000 dummy files. To make that into a different number, simply make the change below.
#> 

$TargetDirectory = "d:\temp"

$ffNames = @(
"Cloud", "Tifa", "Barret", "Aerith", "Sephiroth", "Zack", "Cid", "Vincent", "Yuffie", "RedXIII",
"Squall", "Rinoa", "Zell", "Quistis", "Selphie", "Irvine", "Laguna", "Seifer", "Ultimecia",
"Tidus", "Yuna", "Wakka", "Lulu", "Kimahri", "Auron", "Jecht", "Rikku", "Paine",
"Vaan", "Penelo", "Ashe", "Balthier", "Fran", "Basch", "Larsa", "Gabranth", "Cidolfus",
"Noctis", "Ignis", "Gladiolus", "Prompto", "Lunafreya", "Ardyn", "Aranea", "Cid", "Ravus",
"Lightning", "Snow", "Hope", "Sazh", "Vanille", "Fang", "Serah", "Cidney", "Caius",
"Terra", "Locke", "Celes", "Edgar", "Sabin", "Setzer", "Gau", "Strago", "Relm",
"Shantotto", "Zidane", "Vivi", "Steiner", "Freya", "Kuja", "Amarant", "Garnet", "Eiko",
"Twewy", "Nooj", "Bartholomew", "Balthier", "Cid", "Cidolfus", "Cid Garlond", "Cid Raines",
"Shiva", "Ifrit", "Ramuh", "Bahamut", "Odin", "Alexander", "Knights of the Round",
"Y'shtola", "Thancred", "Urianger", "Alphinaud", "Alisaie", "Estinien", "Haurchefant",
"Minfilia", "Lyse", "G'raha", "Cid Nan Garlond"
)

$minecraftNames = @(
"Steve", "Alex", "Creeper", "Zombie", "Skeleton", "Enderman", "Spider", "Slime", "Witch", "Villager",
"IronGolem", "SnowGolem", "Wither", "EnderDragon", "Piglin", "Hoglin", "Strider", "Drowned", "Phantom", "Guardian",
"Elytra", "Diamond", "GoldIngot", "IronIngot", "Coal", "Redstone", "LapisLazuli", "Emerald", "Netherite", "Quartz",
"Obsidian", "Glowstone", "Torch", "Furnace", "CraftingTable", "Anvil", "EnchantmentTable", "Beacon", "Bucket", "Shovel",
"Pickaxe", "Axe", "Sword", "Bow", "Crossbow", "Arrow", "FishingRod", "Shield", "Helmet", "Chestplate",
"Leggings", "Boots", "Bread", "Apple", "Carrot", "Potato", "Melon", "Pumpkin", "Cactus", "SugarCane",
"Oak", "Birch", "Spruce", "Jungle", "Acacia", "DarkOak", "Cobblestone", "Stone", "Dirt", "GrassBlock",
"Sand", "Gravel", "Clay", "MossyCobblestone", "Ice", "SnowBlock", "Cake", "Egg", "Leather", "Rabbit",
"Sheep", "Cow", "Pig", "Chicken", "Horse", "Donkey", "Llama", "Parrot", "Fox", "Bee",
"Nether", "End", "Overworld", "Biome", "Stronghold", "Village", "Minecart", "Rails", "RedstoneTorch", "DaylightSensor"
)

$marioNames = @(
"Mario", "Luigi", "PrincessPeach", "Bowser", "Toad", "Yoshi", "DonkeyKong", "DiddyKong", "Wario", "Waluigi",
"Toadette", "Rosalina", "Daisy", "KoopaTroopa", "Goomba", "ShyGuy", "Boo", "DryBones", "Birdo", "BowserJr",
"KingBoo", "Fawful", "CaptainToad", "MontyMole", "Lakitu", "ChainChomp", "Kamek", "HammerBro", "PeteyPiranha", "MegaMushroom",
"Spike", "CheepCheep", "Pokey", "Thwomp", "BobOmb", "BulletBill", "Fuzzy", "Goomba", "Wiggler", "PiranhaPlant",
"Blooper", "KoopaParatroopa", "BoomBoom", "PomPom", "IggyKoopa", "LudwigVonKoopa", "MortonKoopaJr", "LarryKoopa", "RoyKoopa", "WendyOKoopa"
)

$sonicNames = @(
"Sonic", "Tails", "Knuckles", "Amy", "DrEggman", "Shadow", "Rouge", "Silver", "Blaze", "Cream"
)

$wordList = $ffNames + $minecraftNames + $marioNames + $sonicNames

# Ensure the directory exists, if not will be created then generate junk files.
if (-not (Test-Path -Path $TargetDirectory)) {
    New-Item -ItemType Directory -Path $TargetDirectory | Out-Null
}

Write-Host "Generating Random Junk Files ... "

for ($i = 1; $i -le 5000; $i++) {
    # Pick two random words from the list
    $word1 = Get-Random -InputObject $wordList
    $word2 = Get-Random -InputObject $wordList

    # Combine them with an underscore for the file name
    $RandomFileName = "$word1 $word2.txt"

    # Full file path
    $filePath = Join-Path -Path $TargetDirectory -ChildPath $RandomFileName

    # Timestamp string
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Create the file and insert the timestamp inside
    Set-Content -Path $filePath -Value "File created on $timestamp"
}

Write-Host "$i dummy files with timestamp created in $TargetDirectory"
