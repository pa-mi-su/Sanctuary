import fs from 'fs';
import path from 'path';

const root = '/Users/pms/Documents/Projects/Sanctuary';
const saintsDir = path.join(root, 'Sanctuary/Resources/LegacyData/saints');
const novenasDir = path.join(root, 'Sanctuary/Resources/LegacyData/novenas');

function readJSON(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function writeJSON(file, value) {
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

const saintFixes = {
  '02-28_saint_angela_of_foligno': {
    name: 'Saint Angela of Foligno',
    name_es: 'Santa Ángela de Foligno',
    name_pl: 'Święta Angela z Foligno',
    summary: 'Saint Angela of Foligno was an Italian Franciscan tertiary, mystic, and penitent whose conversion led her to a life of poverty, prayer, and deep union with Christ.',
    summary_es: 'Santa Ángela de Foligno fue una terciaria franciscana italiana, mística y penitente, cuya conversión la llevó a una vida de pobreza, oración y profunda unión con Cristo.',
    summary_pl: 'Święta Angela z Foligno była włoską tercjarką franciszkańską, mistyczką i pokutnicą, której nawrócenie poprowadziło ją do życia w ubóstwie, modlitwie i głębokiej jedności z Chrystusem.',
    biography: 'Saint Angela of Foligno (c. 1248-1309) was a wife and mother who, after the deaths of her family members, embraced a profound conversion of heart. She joined the Secular Franciscan movement and became known for her radical penance, love of the poor, and intense meditations on the Passion of Christ. Her spiritual counsels and mystical experiences made her one of the best-known Franciscan women of the Middle Ages. The Church honors her as a witness to mercy, repentance, and total surrender to God.',
    biography_es: 'Santa Ángela de Foligno (c. 1248-1309) fue esposa y madre que, tras la muerte de varios miembros de su familia, abrazó una profunda conversión del corazón. Se unió al movimiento franciscano seglar y llegó a ser conocida por su penitencia radical, su amor a los pobres y sus intensas meditaciones sobre la Pasión de Cristo. Sus consejos espirituales y experiencias místicas la convirtieron en una de las mujeres franciscanas más conocidas de la Edad Media. La Iglesia la honra como testigo de la misericordia, la penitencia y la entrega total a Dios.',
    biography_pl: 'Święta Angela z Foligno (ok. 1248-1309) była żoną i matką, która po śmierci członków swojej rodziny przeszła głębokie nawrócenie serca. Dołączyła do franciszkańskiego ruchu świeckich i zasłynęła z radykalnej pokuty, miłości do ubogich oraz intensywnych rozważań nad Męką Chrystusa. Jej rady duchowe i doświadczenia mistyczne uczyniły ją jedną z najbardziej znanych franciszkanek średniowiecza. Kościół czci ją jako świadka miłosierdzia, pokuty i całkowitego oddania się Bogu.'
  },
  '05-03_saints_philip_and_james': {
    name: 'Saints Philip and James, Apostles',
    name_es: 'Santos Felipe y Santiago, Apóstoles',
    name_pl: 'Święci Filip i Jakub, Apostołowie',
    summary: 'Saints Philip and James are honored together in the Roman Rite as apostles of the Lord and steadfast witnesses to the Resurrection.',
    summary_es: 'Los santos Felipe y Santiago son honrados juntos en el rito romano como apóstoles del Señor y testigos firmes de la Resurrección.',
    summary_pl: 'Święci Filip i Jakub są czczeni razem w rycie rzymskim jako apostołowie Pana i wierni świadkowie Zmartwychwstania.',
    biography: 'Saint Philip was among the first disciples called by Jesus and is remembered in the Gospels for bringing others to the Lord and asking to see the Father. Saint James the Less, son of Alphaeus, is honored as an apostle and an early leader of the Church at Jerusalem. Their shared feast celebrates apostolic faith, missionary zeal, and the witness of the first generation who proclaimed Christ to the world.',
    biography_es: 'San Felipe fue uno de los primeros discípulos llamados por Jesús y es recordado en los Evangelios por llevar a otros al Señor y por pedir ver al Padre. Santiago el Menor, hijo de Alfeo, es honrado como apóstol y como uno de los primeros dirigentes de la Iglesia de Jerusalén. Su fiesta común celebra la fe apostólica, el celo misionero y el testimonio de la primera generación que anunció a Cristo al mundo.',
    biography_pl: 'Święty Filip należał do pierwszych uczniów powołanych przez Jezusa i w Ewangeliach jest wspominany jako ten, który przyprowadzał innych do Pana i prosił, by zobaczyć Ojca. Święty Jakub Mniejszy, syn Alfeusza, jest czczony jako apostoł i jeden z pierwszych przywódców Kościoła jerozolimskiego. Ich wspólne święto sławi wiarę apostolską, zapał misyjny i świadectwo pierwszego pokolenia, które głosiło Chrystusa światu.'
  },
  '06-30_the_first_martyrs_of_the_holy_roman_church': {
    name: 'The First Martyrs of the Holy Roman Church',
    name_es: 'Los Primeros Mártires de la Santa Iglesia Romana',
    name_pl: 'Pierwsi Męczennicy Świętego Kościoła Rzymskiego',
    summary: 'This memorial honors the Christians put to death in Rome during Nero\'s persecution after the great fire, the first great outpouring of martyrdom in the capital of the Church.',
    summary_es: 'Esta conmemoración honra a los cristianos que fueron ejecutados en Roma durante la persecución de Nerón después del gran incendio, la primera gran efusión de martirio en la capital de la Iglesia.',
    summary_pl: 'To wspomnienie czci chrześcijan zabitych w Rzymie podczas prześladowania Nerona po wielkim pożarze, pierwszego wielkiego rozlewu męczeństwa w stolicy Kościoła.',
    biography: 'The First Martyrs of the Holy Roman Church were the unnamed Christians who suffered in Rome under Emperor Nero around A.D. 64. Ancient tradition remembers them as victims of brutal punishments after Nero blamed Christians for the fire that devastated the city. Their feast, celebrated the day after Saints Peter and Paul, reminds the Church that the witness of Rome was sealed not only by its great apostles but also by many hidden believers who gave their lives for Christ.',
    biography_es: 'Los Primeros Mártires de la Santa Iglesia Romana fueron los cristianos sin nombre que padecieron en Roma bajo el emperador Nerón hacia el año 64 d.C. La antigua tradición los recuerda como víctimas de castigos brutales después de que Nerón culpara a los cristianos del incendio que devastó la ciudad. Su fiesta, celebrada al día siguiente de san Pedro y san Pablo, recuerda a la Iglesia que el testimonio de Roma fue sellado no solo por sus grandes apóstoles, sino también por muchos creyentes ocultos que entregaron su vida por Cristo.',
    biography_pl: 'Pierwsi Męczennicy Świętego Kościoła Rzymskiego to bezimienni chrześcijanie, którzy cierpieli w Rzymie za cesarza Nerona około 64 roku. Starożytna tradycja wspomina ich jako ofiary okrutnych kar po tym, jak Neron obwinił chrześcijan o pożar, który zniszczył miasto. Ich wspomnienie, obchodzone dzień po świętych Piotrze i Pawle, przypomina Kościołowi, że świadectwo Rzymu zostało przypieczętowane nie tylko przez wielkich apostołów, ale także przez wielu ukrytych wierzących, którzy oddali życie za Chrystusa.'
  },
  '07-02_blessed_virgin_mary_to_elizabeth': {
    name: 'The Visitation of the Blessed Virgin Mary',
    name_es: 'La Visitación de la Santísima Virgen María',
    name_pl: 'Nawiedzenie Najświętszej Maryi Panny',
    summary: 'The Visitation commemorates Mary\'s journey to Elizabeth, where the unborn John the Baptist leapt for joy and the Virgin proclaimed the Magnificat.',
    summary_es: 'La Visitación conmemora el viaje de María a casa de Isabel, donde san Juan Bautista saltó de alegría en el seno materno y la Virgen proclamó el Magníficat.',
    summary_pl: 'Nawiedzenie upamiętnia podróż Maryi do Elżbiety, podczas której nienarodzony Jan Chrzciciel poruszył się z radości, a Dziewica wyśpiewała Magnificat.',
    biography: 'The Visitation of the Blessed Virgin Mary celebrates the Gospel meeting between Mary and her kinswoman Elizabeth. Bearing Christ within her, Mary hastened to serve and console Elizabeth, and at her greeting the child in Elizabeth\'s womb leapt for joy. Elizabeth acclaimed Mary as the Mother of the Lord, and Mary answered with the Magnificat, the Church\'s great canticle of praise. This feast honors charity, humility, and the joy that comes from Christ\'s presence.',
    biography_es: 'La Visitación de la Santísima Virgen María celebra el encuentro evangélico entre María y su parienta Isabel. Llevando a Cristo en su seno, María fue presurosa a servir y consolar a Isabel, y al oír su saludo el niño en el seno de Isabel saltó de alegría. Isabel aclamó a María como Madre del Señor, y María respondió con el Magníficat, el gran cántico de alabanza de la Iglesia. Esta fiesta honra la caridad, la humildad y la alegría que brota de la presencia de Cristo.',
    biography_pl: 'Nawiedzenie Najświętszej Maryi Panny celebruje ewangeliczne spotkanie Maryi z jej krewną Elżbietą. Niosąc w sobie Chrystusa, Maryja pospieszyła, by służyć i pocieszyć Elżbietę, a na dźwięk Jej pozdrowienia dziecko w łonie Elżbiety poruszyło się z radości. Elżbieta ogłosiła Maryję Matką Pana, a Maryja odpowiedziała Magnificat, wielkim hymnem uwielbienia Kościoła. To święto czci miłość, pokorę i radość płynącą z obecności Chrystusa.'
  },
  '08-06_the_transfiguration_of_the_lord': {
    name: 'The Transfiguration of the Lord',
    name_es: 'La Transfiguración del Señor',
    name_pl: 'Przemienienie Pańskie',
    summary: 'The Transfiguration reveals Christ\'s divine glory on the mountain before Peter, James, and John, strengthening the Church for the way of the Cross.',
    summary_es: 'La Transfiguración revela la gloria divina de Cristo en el monte ante Pedro, Santiago y Juan, fortaleciendo a la Iglesia para el camino de la Cruz.',
    summary_pl: 'Przemienienie objawia Boską chwałę Chrystusa na górze wobec Piotra, Jakuba i Jana, umacniając Kościół na drogę Krzyża.',
    biography: 'The Feast of the Transfiguration of the Lord remembers the moment when Jesus was transfigured on the mountain and His face shone like the sun. Moses and Elijah appeared with Him, and the Father\'s voice declared, “This is my beloved Son; listen to him.” The Church celebrates this mystery as a revelation of Christ\'s glory, a confirmation of His divine sonship, and a foretaste of the Resurrection given to strengthen the disciples before the Passion.',
    biography_es: 'La Fiesta de la Transfiguración del Señor recuerda el momento en que Jesús se transfiguró en el monte y su rostro resplandeció como el sol. Moisés y Elías aparecieron con Él, y la voz del Padre proclamó: «Este es mi Hijo amado; escuchadlo». La Iglesia celebra este misterio como revelación de la gloria de Cristo, confirmación de su filiación divina y anticipo de la Resurrección concedido para fortalecer a los discípulos antes de la Pasión.',
    biography_pl: 'Święto Przemienienia Pańskiego wspomina chwilę, gdy Jezus przemienił się na górze, a Jego oblicze zajaśniało jak słońce. Ukazali się przy Nim Mojżesz i Eliasz, a głos Ojca ogłosił: „To jest mój Syn umiłowany, Jego słuchajcie”. Kościół celebruje tę tajemnicę jako objawienie chwały Chrystusa, potwierdzenie Jego Boskiego synostwa i zapowiedź Zmartwychwstania daną po to, by umocnić uczniów przed Męką.'
  },
  '03-02_saint_jovinus': {
    summary: 'Saint Jovinus is remembered in Christian tradition as an early witness to Christ whose memory has been preserved by the Church even though few historical details survive.',
    summary_es: 'San Jovino es recordado en la tradición cristiana como un testigo antiguo de Cristo cuya memoria ha sido conservada por la Iglesia, aunque se han conservado pocos datos históricos.',
    summary_pl: 'Święty Jowin jest wspominany w tradycji chrześcijańskiej jako wczesny świadek Chrystusa, którego pamięć zachował Kościół, choć przetrwało niewiele szczegółów historycznych.',
    biography: 'Saint Jovinus is commemorated by the Church on March 2. Historical details about his life are scarce, but his place in the sanctoral tradition testifies to the enduring memory of holy men and women whose fidelity to Christ was treasured by the early Church. His remembrance invites the faithful to honor not only the most famous saints, but also those whose witness has come down to us quietly through the Church\'s prayer.',
    biography_es: 'San Jovino es conmemorado por la Iglesia el 2 de marzo. Los datos históricos sobre su vida son escasos, pero su lugar en la tradición de los santos testimonia la memoria perdurable de hombres y mujeres santos cuya fidelidad a Cristo fue apreciada por la Iglesia primitiva. Su recuerdo invita a los fieles a honrar no solo a los santos más famosos, sino también a aquellos cuyo testimonio ha llegado hasta nosotros discretamente a través de la oración de la Iglesia.',
    biography_pl: 'Święty Jowin jest wspominany przez Kościół 2 marca. Historyczne szczegóły dotyczące jego życia są skąpe, ale jego miejsce w tradycji świętych świadczy o trwałej pamięci o świętych mężczyznach i kobietach, których wierność Chrystusowi była ceniona przez pierwotny Kościół. Jego wspomnienie zachęca wiernych, aby czcili nie tylko najbardziej znanych świętych, lecz także tych, których świadectwo dotarło do nas dyskretnie poprzez modlitwę Kościoła.'
  },
  '05-11_saint_evelius': {
    summary: 'Saint Evelius is remembered in the Roman martyrological tradition as a faithful Christian witness, although only limited historical details about him have come down to us.',
    summary_es: 'San Evelio es recordado en la tradición martirológica romana como un fiel testigo cristiano, aunque hasta nosotros han llegado pocos detalles históricos sobre él.',
    summary_pl: 'Święty Eweliusz jest wspominany w tradycji martyrologicznej Kościoła rzymskiego jako wierny świadek chrześcijański, choć zachowało się niewiele szczegółów historycznych na jego temat.',
    biography: 'Saint Evelius is honored by the Church as one of the lesser-known saints whose names have been preserved in Christian memory. While the historical record is sparse, his commemoration reflects the Church\'s reverence for believers who remained steadfast in faith and whose witness strengthened the community of the faithful. His feast is a reminder that holiness is known perfectly to God even when history remembers only a name.',
    biography_es: 'San Evelio es honrado por la Iglesia como uno de esos santos menos conocidos cuyos nombres se han conservado en la memoria cristiana. Aunque el registro histórico es escaso, su conmemoración refleja la veneración de la Iglesia por los creyentes que permanecieron firmes en la fe y cuyo testimonio fortaleció a la comunidad de los fieles. Su fiesta recuerda que la santidad es conocida perfectamente por Dios incluso cuando la historia conserva solo un nombre.',
    biography_pl: 'Święty Eweliusz jest czczony przez Kościół jako jeden z mniej znanych świętych, których imiona zachowały się w pamięci chrześcijańskiej. Chociaż zapis historyczny jest skromny, jego wspomnienie odzwierciedla cześć Kościoła dla wierzących, którzy trwali mocno w wierze i których świadectwo umacniało wspólnotę wiernych. Jego święto przypomina, że świętość jest doskonale znana Bogu nawet wtedy, gdy historia zachowuje jedynie imię.'
  },
  '08-29_the_passion_of_saint_john_the_baptist_martyr_memorial': {
    name: 'The Passion of Saint John the Baptist',
    name_es: 'La Pasión de San Juan Bautista',
    name_pl: 'Męczeństwo św. Jana Chrzciciela',
    summary: 'This memorial commemorates the martyrdom of Saint John the Baptist, the forerunner of the Lord, who was imprisoned and beheaded for the sake of truth.',
    summary_es: 'Esta memoria conmemora el martirio de san Juan Bautista, precursor del Señor, que fue encarcelado y decapitado por causa de la verdad.',
    summary_pl: 'To wspomnienie upamiętnia męczeństwo świętego Jana Chrzciciela, poprzednika Pana, który został uwięziony i ścięty za prawdę.',
    biography: 'The Passion of Saint John the Baptist recalls the death of the last prophet and immediate precursor of Christ. John denounced Herod\'s unlawful marriage and, for his fidelity to God\'s law, was imprisoned and eventually beheaded at the request of Herodias\'s daughter. The Church venerates his martyrdom as the witness of a man who preferred truth to favor and obedience to God over fear of earthly power.',
    biography_es: 'La Pasión de san Juan Bautista recuerda la muerte del último profeta y precursor inmediato de Cristo. Juan denunció el matrimonio ilícito de Herodes y, por su fidelidad a la ley de Dios, fue encarcelado y finalmente decapitado a petición de la hija de Herodías. La Iglesia venera su martirio como el testimonio de un hombre que prefirió la verdad al favor humano y la obediencia a Dios al temor del poder terreno.',
    biography_pl: 'Męczeństwo świętego Jana Chrzciciela przypomina śmierć ostatniego proroka i bezpośredniego poprzednika Chrystusa. Jan potępił bezprawne małżeństwo Heroda i za wierność Bożemu prawu został uwięziony, a ostatecznie ścięty na żądanie córki Herodiady. Kościół czci jego męczeństwo jako świadectwo człowieka, który przedkładał prawdę nad ludzkie względy, a posłuszeństwo Bogu nad lęk przed ziemską władzą.'
  }
};

for (const [id, patch] of Object.entries(saintFixes)) {
  const file = path.join(saintsDir, `${id}.json`);
  const doc = readJSON(file);
  Object.assign(doc, patch);
  doc.prayers = Array.isArray(doc.prayers) ? doc.prayers : [];
  doc.sources = [];
  doc.photoUrl = null;
  delete doc._translationMeta;
  writeJSON(file, doc);
}

{
  const id = 'st_joachim';
  const file = path.join(novenasDir, `${id}.json`);
  const doc = readJSON(file);
  doc.description = 'Honor Saint Joachim, father of the Blessed Virgin Mary, and ask his intercession for grandparents, parents, and families seeking steadfast faith.';
  doc.description_es = 'Honra a san Joaquín, padre de la Santísima Virgen María, y pide su intercesión por los abuelos, los padres y las familias que buscan una fe firme.';
  doc.description_pl = 'Uczcij świętego Joachima, ojca Najświętszej Maryi Panny, i proś o jego wstawiennictwo za dziadków, rodziców oraz rodziny szukające mocnej wiary.';
  writeJSON(file, doc);
}

{
  const id = 'st_elizabeth_of_hungary';
  const file = path.join(novenasDir, `${id}.json`);
  const doc = readJSON(file);
  doc.title_es = 'Novena a Santa Isabel de Hungría';
  doc.title_pl = 'Nowenna do św. Elżbiety Węgierskiej';
  doc.description_es = 'Santa Isabel de Hungría fue una princesa del siglo XIII, esposa y madre, famosa por su amor a los pobres y por sus obras de misericordia. Reza esta novena por los necesitados, las viudas, las familias y quienes sirven a los pobres.';
  doc.description_pl = 'Święta Elżbieta Węgierska była trzynastowieczną księżniczką, żoną i matką, znaną z miłości do ubogich oraz dzieł miłosierdzia. Módl się tą nowenną za ubogich, wdowy, rodziny i wszystkich, którzy służą potrzebującym.';
  const prayerEs = 'En el Nombre del Padre, y del Hijo, y del Espíritu Santo. Amén.\n\nBienaventurada Isabel, vaso escogido de virtudes excelsas, muestras al mundo lo que la fe, la esperanza y la caridad pueden obrar en un alma cristiana. Empleaste todas las fuerzas de tu corazón en amar solo a Dios. Lo amaste con un amor tan puro y ferviente que te hizo digna de gustar ya en la tierra los favores y dulzuras del paraíso comunicados a las almas invitadas a las bodas del divino Cordero de Dios. Iluminada por la luz sobrenatural y por una fe inquebrantable, te mostraste verdadera hija del santo Evangelio, al reconocer en tu prójimo la Persona de nuestro Señor Jesucristo, único objeto de tus afectos. Por eso ponías toda tu alegría en conversar con los pobres, servirlos, secar sus lágrimas, consolar sus espíritus y asistirlos con toda obra piadosa en medio de la peste y de las miserias a las que está sujeta nuestra naturaleza humana. (menciona aquí tu intención...)\n\nTe hiciste pobre para socorrer a tu prójimo en su pobreza, pobre en los bienes de la tierra para enriquecerte con los bienes del cielo. Fuiste tan humilde que, después de cambiar un trono por una pobre choza y un manto real por el humilde hábito de san Francisco, te sometiste, aun siendo inocente, a una vida de privación y penitencia, y con santa alegría abrazaste la cruz de tu Redentor, aceptando con Él los insultos y la más injusta persecución. Así olvidaste al mundo y a ti misma para recordar solo a tu Dios. Querida santa, tan amada por Dios, dígnate ser amiga celestial de nuestras almas y ayúdalas a ser cada vez más agradables a Jesús. Desde lo alto del cielo dirige sobre nosotros una de esas miradas llenas de ternura que, cuando estabas en la tierra, curaban las enfermedades más dolorosas. En esta época nuestra, tan depravada y corrompida y al mismo tiempo tan fría e indiferente a las cosas de Dios, acudimos a ti con confianza para recibir de nuestro Señor luz para el entendimiento y fortaleza para la voluntad, y así obtener la paz del alma. Mientras bendecimos al Señor por haber glorificado su Nombre en este mundo con el esplendor de tus virtudes heroicas y con la recompensa eterna concedida a ellas, querida santa Isabel, desde ese trono bienaventurado que ocupas junto al Santo de los santos, protégenos en nuestra peligrosa peregrinación, obtén para nosotros el perdón de nuestros pecados y ábrenos el camino para entrar y compartir contigo el Reino de Dios. Amén.\n\nEn el Nombre del Padre, y del Hijo, y del Espíritu Santo. Amén.';
  const prayerPl = 'W imię Ojca i Syna, i Ducha Świętego. Amen.\n\nBłogosławiona Elżbieto, naczynie wybrane wzniosłych cnót, ukazujesz światu, czego wiara, nadzieja i miłość mogą dokonać w chrześcijańskiej duszy. Wszystkie siły swego serca poświęciłaś, aby kochać jedynie Boga. Kochałaś Go miłością tak czystą i gorącą, że już na ziemi zasłużyłaś kosztować tych łask i słodyczy nieba, które są udzielane duszom zaproszonym na gody Boskiego Baranka. Oświecona światłem nadprzyrodzonym i niewzruszoną wiarą okazałaś się prawdziwą córką świętej Ewangelii, dostrzegając w osobie bliźniego samego Pana Jezusa Chrystusa, jedyny przedmiot swoich uczuć. Dlatego znajdowałaś największą radość w obcowaniu z ubogimi, w służeniu im, w osuszaniu ich łez, pocieszaniu ich serc i spieszeniu im z każdą pobożną pomocą pośród zarazy i nędz, którym podlega nasza ludzka natura. (wymień tutaj swoją intencję...)\n\nStałaś się uboga, aby zaradzić ubóstwu bliźniego — uboga w dobra ziemskie, aby ubogacić się dobrami nieba. Byłaś tak pokorna, że po zamianie tronu na ubogą chatę i królewskiego płaszcza na skromny habit świętego Franciszka poddałaś się, choć niewinna, życiu wyrzeczenia i pokuty, i z świętą radością objęłaś krzyż Odkupiciela, wraz z Nim przyjmując obelgi i najbardziej niesprawiedliwe prześladowanie. W ten sposób zapomniałaś o świecie i o sobie, aby pamiętać tylko o Bogu. Najdroższa Święta, tak umiłowana przez Boga, racz być niebieską przyjaciółką naszych dusz i pomagaj im stawać się coraz milszymi Jezusowi. Ze szczytu nieba skieruj ku nam jedno z tych czułych spojrzeń, które za twego życia uzdrawiały najboleśniejsze słabości. W naszych czasach, tak zepsutych i skażonych, a zarazem tak chłodnych i obojętnych wobec spraw Bożych, uciekamy się do ciebie z ufnością, aby otrzymać od Pana światło dla rozumu i siłę dla woli, a przez to pokój duszy. Błogosławiąc Pana za to, że uwielbił swe Imię w tym świecie blaskiem twoich heroicznych cnót i wieczną nagrodą im przyznaną, droga święta Elżbieto, z tego błogosławionego tronu, który zajmujesz blisko Świętego nad świętymi, chroń nas w naszej niebezpiecznej pielgrzymce, wyjednaj nam przebaczenie grzechów i otwórz nam drogę, byśmy mogli wejść i wraz z tobą uczestniczyć w Królestwie Bożym. Amen.\n\nW imię Ojca i Syna, i Ducha Świętego. Amen.';
  for (const day of doc.days ?? []) {
    day.prayer_es = prayerEs;
    day.prayer_pl = prayerPl;
  }
  writeJSON(file, doc);
}

for (const id of ['cardinal_burke_our_lady_of_guadalupe', 'one_year_st_bridget_of_sweden']) {
  const file = path.join(novenasDir, `${id}.json`);
  const doc = readJSON(file);
  doc.status = 'draft';
  writeJSON(file, doc);
}

console.log('Applied content audit fixes.');
