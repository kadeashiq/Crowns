import Foundation

/// Brands and model families offered while typing a watch in by hand.
enum WatchCatalog {
    /// A suggestion to fill in. `model` is empty when only the brand is known.
    struct Match: Identifiable, Hashable {
        let brand: String
        var model = ""

        var id: String { brand + "|" + model }
        var title: String { model.isEmpty ? brand : brand + " " + model }
    }

    /// Popular brands first, each with its best-known model families.
    private static let families: [(brand: String, models: [String])] = [
        ("Rolex", ["Submariner", "Submariner Date", "GMT-Master II", "Datejust", "Datejust 31", "Datejust 36", "Datejust 41", "Day-Date", "Cosmograph Daytona", "Explorer", "Explorer II", "Sea-Dweller", "Deepsea", "Yacht-Master", "Yacht-Master II", "Sky-Dweller", "Air-King", "Oyster Perpetual", "Milgauss", "1908", "Land-Dweller", "Oysterquartz"]),
        ("Omega", ["Speedmaster Professional", "Speedmaster Moonwatch", "Speedmaster Reduced", "Speedmaster '57", "Speedmaster Racing", "Seamaster Diver 300M", "Seamaster Planet Ocean", "Seamaster Aqua Terra", "Seamaster 300", "Constellation", "De Ville", "De Ville Prestige", "Railmaster", "MoonSwatch"]),
        ("Patek Philippe", ["Nautilus", "Aquanaut", "Calatrava", "Golden Ellipse", "Gondolo", "Twenty~4", "Cubitus", "Grand Complications", "Annual Calendar", "World Time"]),
        ("Audemars Piguet", ["Royal Oak", "Royal Oak Offshore", "Royal Oak Concept", "Code 11.59", "Millenary", "Jules Audemars"]),
        ("Cartier", ["Tank", "Tank Must", "Tank Française", "Tank Louis Cartier", "Tank Américaine", "Santos", "Santos-Dumont", "Ballon Bleu", "Panthère", "Pasha", "Drive", "Crash", "Baignoire", "Ronde"]),
        ("Tudor", ["Black Bay", "Black Bay 54", "Black Bay 58", "Black Bay GMT", "Black Bay Chrono", "Pelagos", "Pelagos 39", "Ranger", "Royal", "1926", "Heritage Chrono"]),
        ("Seiko", ["Prospex", "Presage", "Astron", "5 Sports", "SKX007", "SKX009", "Alpinist", "Turtle", "Samurai", "Sumo", "Tuna", "Cocktail Time", "Solar", "Kinetic"]),
        ("Grand Seiko", ["Snowflake", "Spring Drive", "Heritage", "Evolution 9", "Elegance", "Sport", "White Birch", "Shunbun"]),
        ("TAG Heuer", ["Carrera", "Monaco", "Aquaracer", "Formula 1", "Autavia", "Link"]),
        ("Breitling", ["Navitimer", "Superocean", "Superocean Heritage", "Chronomat", "Chronomat Automatic", "Avenger", "Premier", "Top Time", "Endurance Pro"]),
        ("IWC", ["Portugieser", "Pilot's Watch", "Big Pilot", "Mark XX", "Portofino", "Aquatimer", "Ingenieur", "Da Vinci"]),
        ("Panerai", ["Luminor", "Luminor Marina", "Luminor Due", "Radiomir", "Submersible"]),
        ("Hublot", ["Big Bang", "Classic Fusion", "Spirit of Big Bang", "Square Bang"]),
        ("Jaeger-LeCoultre", ["Reverso", "Master Ultra Thin", "Master Control", "Polaris", "Rendez-Vous", "Atmos", "Duomètre"]),
        ("Vacheron Constantin", ["Overseas", "Patrimony", "Traditionnelle", "Fiftysix", "Historiques", "Égérie"]),
        ("A. Lange & Söhne", ["Lange 1", "Saxonia", "Datograph", "Zeitwerk", "1815", "Odysseus", "Little Lange 1"]),
        ("Longines", ["Spirit", "Spirit Zulu Time", "HydroConquest", "Master Collection", "Legend Diver", "Conquest", "Heritage", "DolceVita", "Ultra-Chron", "Flagship"]),
        ("Tissot", ["PRX", "Seastar", "Le Locle", "Gentleman", "Visodate", "Heritage", "T-Touch", "Supersport", "Chemin des Tourelles"]),
        ("Hamilton", ["Khaki Field", "Khaki Field Mechanical", "Khaki Aviation", "Khaki Navy", "Jazzmaster", "Ventura", "American Classic", "Intra-Matic", "Pan Europ", "Boulton"]),
        ("Oris", ["Aquis", "Aquis Date", "Big Crown", "Big Crown Pointer Date", "Divers Sixty-Five", "ProPilot", "Artelier"]),
        ("Zenith", ["Chronomaster Sport", "Chronomaster Original", "El Primero", "Defy", "Defy Skyline", "Elite", "Pilot"]),
        ("Blancpain", ["Fifty Fathoms", "Villeret", "Léman", "Air Command", "Ladybird"]),
        ("Breguet", ["Classique", "Marine", "Type XX", "Tradition", "Reine de Naples", "Héritage"]),
        ("Piaget", ["Polo", "Altiplano", "Limelight", "Possession"]),
        ("Chopard", ["Alpine Eagle", "Happy Sport", "Mille Miglia", "L.U.C", "Imperiale"]),
        ("Girard-Perregaux", ["Laureato", "1966", "Vintage 1945", "Bridges"]),
        ("Ulysse Nardin", ["Marine", "Diver", "Freak", "Blast", "Classico"]),
        ("Bell & Ross", ["BR 03", "BR 05", "BR V2", "BR-X1"]),
        ("Montblanc", ["1858", "Star Legacy", "Heritage", "Summit", "TimeWalker"]),
        ("Nomos Glashütte", ["Tangente", "Orion", "Ludwig", "Club", "Club Campus", "Metro", "Ahoi", "Tetra", "Zürich"]),
        ("Sinn", ["556", "104", "356", "U1", "U50", "EZM 3", "EZM 13", "103"]),
        ("Junghans", ["Max Bill", "Meister", "Form A", "1972"]),
        ("Christopher Ward", ["C60 Trident", "C60 Sapphire", "C63 Sealander", "C65 Trident", "C1 Grand Malvern", "Twelve", "Bel Canto"]),
        ("Bremont", ["Supermarine", "Terra Nova", "Altitude", "ALT1", "Broadsword", "Solo"]),
        ("Baltic", ["Aquascaphe", "MR01", "HMS 002", "Bicompax", "Prismic", "Tricompax"]),
        ("Citizen", ["Eco-Drive", "Promaster", "Promaster Diver", "Tsuyosa", "Series 8", "Chandler", "Corso", "Nighthawk"]),
        ("Casio", ["G-Shock", "G-Shock Frogman", "G-Shock Mudmaster", "G-Shock CasiOak", "MR-G", "Oceanus", "Edifice", "Pro Trek", "F-91W", "A158W", "A168", "Databank", "AE-1200"]),
        ("Orient", ["Bambino", "Kamasu", "Mako", "Ray", "Star", "Sun and Moon"]),
        ("Swatch", ["Originals", "Sistem51", "Irony", "Skin", "Big Bold"]),
        ("Timex", ["Marlin", "Waterbury", "Weekender", "Expedition", "Q Timex", "Easy Reader", "Ironman", "Giorgio Galli S2"]),
        ("Bulova", ["Lunar Pilot", "Precisionist", "Accutron", "Oceanographer", "Archive", "Sutton"]),
        ("Mido", ["Ocean Star", "Multifort", "Baroncelli", "Commander", "Belluna"]),
        ("Rado", ["Captain Cook", "True", "True Thinline", "DiaStar", "Centrix", "Anatom"]),
        ("Maurice Lacroix", ["Aikon", "Pontos", "Masterpiece", "Eliros"]),
        ("Frederique Constant", ["Classics", "Slimline", "Highlife", "Runabout", "Manufacture"]),
        ("Raymond Weil", ["Freelancer", "Maestro", "Toccata", "Millesime", "Tango", "Parsifal"]),
        ("Baume & Mercier", ["Clifton", "Classima", "Riviera", "Hampton"]),
        ("Glashütte Original", ["PanoMaticLunar", "Senator", "Sixties", "SeaQ", "Seventies"]),
        ("Richard Mille", ["RM 010", "RM 011", "RM 035", "RM 055", "RM 67", "RM 72"]),
        ("Vostok", ["Amphibia", "Komandirskie"]),
        ("Mondaine", ["Classic", "Evo2", "Stop2Go", "Helvetica"]),
        ("Laco", ["Flieger", "Aachen", "Augsburg", "Navy"]),
        ("Stowa", ["Flieger", "Marine", "Antea", "Partitio"]),
        ("Doxa", ["SUB 300", "SUB 200", "SUB 300T", "Army"]),
        ("Monta", ["Oceanking", "Atlas", "Skyquest", "Noble"]),
        ("Farer", ["Lander", "Aqua Compressor"]),
        ("Lorier", ["Neptune", "Olympia", "Falcon", "Gemini", "Hydra"]),
        ("Formex", ["Essence", "Reef", "Field"]),
        ("Squale", ["1521", "2002", "1545", "Sub-39"]),
        ("Victorinox", ["I.N.O.X.", "FieldForce", "Alliance", "Maverick"]),
        ("Luminox", ["Navy SEAL", "Bear Grylls", "Atacama", "F-117 Nighthawk"]),
    ]

    /// Watchmakers cross-checked against Wikidata (CC0), for brands the
    /// listing reader doesn't need to recognise in free text.
    private static let otherBrands = [
        "Anonimo", "Aquastar", "Armand Nicolet", "B.R.M", "Bedat & Co", "Benrus", "Bovet", "Breil", "Bulgari", "Candino",
        "Cecil Purnell", "Czapek", "Daniel Roth", "Ebel", "Eberhard & Co.", "Epos", "Festina", "Fossil", "Glycine", "Hanowa",
        "Harry Winston", "Ice-Watch", "Ingersoll", "Invicta", "Juvenia", "Lemania", "LIP", "Louis Erard", "Manufacture Royale",
        "MB&F", "MeisterSinger", "Movado", "Nixon", "Pequignet", "Poljot", "Raketa", "Roamer", "Roger Dubuis", "Romain Gauthier",
        "Schwarz Etienne", "Sector", "Shinola", "Solvil et Titus", "Stührling", "TechnoMarine", "Titan", "Traser", "Van Cleef & Arpels",
        "Vostok Europe", "Waltham", "West End Watch Co", "Wittnauer", "Yema", "Zeno-Watch",
    ]

    static let brands: [String] = {
        var seen = Set<String>()
        return (families.map(\.brand) + WatchBrands.names + otherBrands).filter { seen.insert(fold($0)).inserted }
    }()

    static var brandsWithModels: [String] { families.map(\.brand) }

    /// Brands to offer for what's been typed. Popular ones first.
    static func brands(matching query: String, limit: Int = 12) -> [Match] {
        let key = fold(query)
        guard !key.isEmpty else { return brands.prefix(limit).map { Match(brand: $0) } }
        guard !brands.contains(where: { fold($0) == key }) else { return [] }
        return ranked(brands, by: { $0 }, key: key).prefix(limit).map { Match(brand: $0) }
    }

    /// Models to offer for what's been typed. Searches every brand until
    /// one has been chosen; a brand we hold no models for offers nothing.
    static func models(matching query: String, brand: String, limit: Int = 12) -> [Match] {
        let key = fold(query)
        let chosen = fold(brand)
        let pool: [Match]
        if chosen.isEmpty {
            guard key.count >= 2 else { return [] }
            pool = families.flatMap { family in family.models.map { Match(brand: family.brand, model: $0) } }
        } else {
            let name = WatchBrands.canonical(brand) ?? brand
            pool = (families.first { fold($0.brand) == fold(name) }?.models ?? []).map { Match(brand: name, model: $0) }
        }
        guard !key.isEmpty else { return Array(pool.prefix(limit)) }
        guard !pool.contains(where: { fold($0.model) == key }) else { return [] }
        return Array(ranked(pool, by: \.model, key: key).prefix(limit))
    }

    /// Names starting with what's typed come first, then names with a later word that does.
    private static func ranked<T>(_ items: [T], by name: (T) -> String, key: String) -> [T] {
        let starts = items.filter { fold(name($0)).hasPrefix(key) }
        let words = items.filter { item in
            let folded = fold(name(item))
            return !folded.hasPrefix(key) && folded.contains(" " + key)
        }
        return starts + words
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
