import Foundation

// WordList.swift
// The school-friendly word list for Word Rush. It is plain text in this file, so you can add
// or remove words any time (just keep them lowercase, separated by spaces).
// The `seeds` are the six-letter words the letters are taken from.

enum WordList {
    static let seeds: [String] = [
        "planet", "garden", "school", "master", "stream", "player", "listen", "winter", "friend", "letter",
        "mother", "animal", "simple", "pencil", "bridge", "castle", "circle", "flower", "forest", "gentle",
        "ground", "island", "jungle", "knight", "lesson", "market", "memory", "minute", "nature", "orange",
        "parent", "people", "pocket", "rabbit", "reason", "record", "safety", "season", "second", "silver",
        "spring", "summer", "system", "ticket", "travel", "valley", "window", "wonder", "yellow", "answer",
        "basket", "button", "camera", "candle", "change", "cheese", "choice", "coffee", "cotton", "dinner",
        "engine", "escape", "famous", "finger", "future", "gather", "golden", "growth", "guitar", "handle",
        "health", "height", "honest", "hunter", "insect", "jacket", "kitten", "ladder", "launch", "leader",
        "middle", "moment", "mirror", "monkey", "normal", "notice", "office", "palace", "plenty", "police",
        "potato", "pretty", "prince", "public", "purple", "rocket", "sample", "screen", "secret", "select",
        "shadow", "shower", "signal", "single", "sketch", "smooth", "soccer", "speech", "spider", "square",
        "stable", "status", "strike", "string", "strong", "studio", "supply", "switch", "symbol", "tablet",
        "target", "throat", "tissue", "tomato", "tongue", "trophy", "turtle", "unique", "update", "useful",
        "volume", "wallet", "wealth", "weight", "winner", "wisdom", "wooden", "worker", "writer"
    ]

    static let words: Set<String> = {
        let sources = [threeLetter, fourLetter, fiveLetter, seeds.joined(separator: " "), extraSix]
        let all = sources.joined(separator: " ")
            .split(whereSeparator: { $0 == " " || $0 == "\n" })
            .map { String($0) }
        return Set(all.filter { word in
            !word.isEmpty && word.allSatisfy { $0.isLowercase && $0.isLetter }
        })
    }()

    private static let threeLetter = """
    ace act add age ago aid aim air all and ant any ape arc are arm art ate bad bag ban bat bay bed bee bet big \
    bit box boy bus but buy cab can cap car cat cow cry cub cup cut dad day den did dig dim dog dot dry due ear \
    eat egg end era eye fan far fat fed fee few fin fit fix fly fog for fun fur gap gas gem get got gum guy had \
    ham has hat hay her hid him his hit hot how hub hug ice ink its jam jar jet job joy key kid kit lab lad lap \
    law lay led leg let lid lie lip lit log lot low mad man map mat may men met mix mud mug nap net new nod nor \
    not now nut oak odd off oil old one our out owl pad pan pay pea pen pet pie pig pin pit pot pro put rag ran \
    rat raw ray red rib rid rim rip rod row rub rug run sad sat saw say sea see set sew she shy sin sip sir sit \
    six ski sky sly son sow spy sum sun tab tag tan tap tax tea ten the tie tin tip toe ton too top toy try tub \
    two urn use van vet via wad war was wax way web wed wet who why win wit won yes yet you zip zoo
    """

    private static let fourLetter = """
    able acid also area army atom aunt baby back ball band bank base bath bean bear beat beef bell belt bend \
    best bike bill bird bite blue boat body bold bone book boom born boss both bowl bulb burn busy cake call \
    calm came camp card care case cash cast cell chat chip city clap clay clip club coal coat code coin cold \
    come cook cool copy corn cost crew crop cube cute dark data date dawn days dead deal dear deck deep deer \
    desk dial diet dirt dish dive door dose down draw drew drop drum duck dust duty each earn ease east easy \
    edge else even ever exam face fact fail fair fall farm fast fear feed feel feet fell felt file fill film \
    find fine fire firm fish fist five flag flat flew flow food foot fork form fort four free from fuel full \
    fund gain game gate gave gift girl give glad glow goal goat gold golf gone good grab grew grid grow gulf \
    hair half hall hand hang hard harm have head heal hear heat held help here hero hide high hill hint hold \
    hole home hope horn host hour huge hunt hurt idea inch into iron item jump jury just keep kick kind king \
    knee knew know lack lady lake lamp land lane last late lazy lead leaf lean left lend less life lift like \
    line link lion list live load loan lock long look lord lose loss lost love luck lung made mail main make \
    male many mark mass math meal mean meat meet melt milk mind mine miss mode moon more most move much must \
    name navy near neck need nest news nice nine node none noon nose note once only open oral over pace pack \
    page paid pain pair pale palm park part pass past path peak pick pile pine pink pipe plan play plot plug \
    plus poem poet pole pond pool poor port pose post pour pray pull pump pure push race rain rank rare rate \
    read real rely rent rest rice rich ride ring rise risk road rock role roll roof room root rope rose rule \
    rush safe sail salt same sand save seat seed seek seem seen self sell send sent ship shoe shop shot show \
    shut sick side sign silk sing sink site size skin slip slow snow soft soil sold sole some song soon sort \
    soul soup spot star stay stem step stop such suit sure swim tail take tale talk tall tank tape task team \
    tear tell tend term test text than that them then they thin this thus tide tidy tile time tiny tire told \
    tone took tool tops town tree trip true tube tune turn twin type unit upon used user vary vast very view \
    vote wait wake walk wall want warm wash wave weak wear week well went were west what when whom wide wife \
    wild will wind wine wing wire wise wish with wolf wood wool word wore work worm yard year yell your zero zone
    """

    private static let fiveLetter = """
    about above actor adult after again agree ahead alarm album alive allow alone along angle angry apple \
    arena argue arise array aside asset audio avoid award aware bacon badge basic basis beach begin being \
    below bench berry black blade blame blank blast blind block blood bloom board boost brain brake brave \
    bread break brick brief bring broad brown brush build bunch burst cabin cable candy carry catch cause \
    chain chair chalk charm chart chase cheap check cheek chess chest chief child chill choir chose civil \
    claim class clean clear clerk click cliff climb clock close cloth cloud coach coast color couch could \
    count court cover craft crash crazy cream crime cross crowd crown cycle daily dance death delay depth \
    dirty doubt dozen draft drama dream dress drift drink drive eager early earth eight elbow empty enemy \
    enjoy enter equal error event every exact extra faith false fault feast fence fever field fifth fifty \
    fight final first flame flash fleet flesh float flood floor flour fluid focus force forth forty found \
    frame fresh front fruit funny ghost giant given glass globe glory grace grade grain grand grant grape \
    grass great green greet grill group guard guess guest guide habit happy harsh heart heavy hello hence \
    honey horse hotel house human humor ideal image inbox index inner input issue ivory jelly jewel joint \
    judge juice knife knock known label labor large laser later laugh layer learn least leave legal lemon \
    level light limit local logic loose lover lower lucky lunch magic major maker march match maybe mayor \
    meant medal media melon metal meter might minor minus mixed model money month moral motor mount mouse \
    mouth movie music nerve never newly night noise north noted novel nurse ocean offer often olive onion \
    opera order other ought outer owner paint panel paper party pasta patch pause peace pearl phone photo \
    piano piece pilot pitch pizza place plain plane plant plate plaza point polar pound power press price \
    pride prime print prior prize proof proud prove pulse queen quick quiet quite radio raise range rapid \
    ratio reach react ready realm refer relax reply rider ridge right river robot rocky rough round route \
    royal rural salad scale scene scope score sense serve seven shade shake shall shape share sharp sheep \
    sheet shelf shell shift shine shirt shock shoot shore short shout sight skill sleep slice slide small \
    smart smile smoke snake solar solid solve sorry sound south space spare speak speed spell spend spice \
    spoke sport staff stage stair stamp stand start state steam steel stick still stock stone stood store \
    storm story strip study stuff style sugar suite sunny super sweet swift swing table taken taste teach \
    teeth thank theme there these thick thing think third those three throw thumb tiger tight tired title \
    today token total touch tough tower trace track trade trail train treat trend trial tribe trick tried \
    truck truly trust truth twice uncle under union unity until upper upset urban usage usual valid value \
    video virus visit vital voice waste watch water wheel where which while white whole whose woman world \
    worry worse worst worth would wound write wrong yield young youth
    """

    private static let extraSix = """
    always anyone appear around basket become before behind belong better beyond bottle branch breath \
    bright broken burden bureau cancel center chance charge cheese circus clever closed coffee comedy \
    corner couple course create damage danger decide design detail dollar double dragon drawer during \
    easily eleven enough entire family farmer father faster fellow figure finish fisher flight follow \
    fourth french garage global ground guilty hammer happen heater hidden holder hotels humble indeed \
    inside invite itself joined junior kettle lately lawyer lights likely listen little lonely mainly \
    manage manner marble matter member merely method modern mostly moving myself narrow nearly number \
    object oldest opened option orange others paying pepper placed planes player prefer prison \
    proper quiet random rather reader really remain remove repair repeat result return reveal review \
    ribbon rescue sailor scheme screen search seldom senior series settle shapes should simple sister \
    smaller social solved sooner source speaks spirit spread stands stream street stress strict studio \
    summer sunset surely taught thanks thirty though threat throne ticket timing toward travel turned \
    twelve twenty unable unless unlike useful valley vendor weekly wheels within wonder wooden worked \
    yellow
    """
}
