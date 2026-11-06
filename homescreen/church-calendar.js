// St. Peter OS: Coptic church calendar, computed on the TV (no internet needed).
// Gives today's Coptic date, feast, season, fasting status and what's coming up.
// Fixed feasts use Coptic dates, except the Nativity cycle, which the Coptic Church
// keeps on Jan 7 (Nativity) and Jan 19 (Theophany) every year.
// Moveable feasts and fasts follow Orthodox (Julian) Easter.
(function (root) {
  const DAY = 86400000;
  const MONTHS = {
    en: ['Tout','Baba','Hatour','Kiahk','Touba','Amshir','Baramhat','Baramouda','Bashans','Paona','Abib','Mesra','Nasie'],
    ar: ['توت','بابه','هاتور','كيهك','طوبة','أمشير','برمهات','برمودة','بشنس','بؤونة','أبيب','مسرى','نسيء']
  };
  // St-Takla.org Synaxarium folders and file suffixes for each Coptic month
  const SYNAX = [['01-toot','tout'],['02-babah','baba'],['03-hatoor','hator'],['04-keyahk','kiahk'],
    ['05-topah','toba'],['06-amsheer','amshir'],['07-baramhat','paramhat'],['08-bermodah','baramouda'],
    ['09-bashans','pashans'],['10-bawoonah','paona'],['11-abeeb','epep'],['12-mesraa','mesra'],['13-nasea','nasie']];

  const utc = (y, m, d) => Date.UTC(y, m - 1, d);
  const dayNum = t => Math.floor(t / DAY);                 // days since 1970-01-01 (UTC dates)
  const N = (en, ar) => ({ en, ar });

  function coptic(t) {
    const jdn = dayNum(t) + 2440588;
    const year = Math.floor((4 * (jdn - 1825030) + 1463) / 1461);
    const start = 1825030 + 365 * (year - 1) + Math.floor(year / 4);
    const doy = jdn - start;
    return { year, month: Math.floor(doy / 30), day: doy % 30 + 1 };   // month 0 = Tout
  }
  function fromCoptic(year, month, day) {
    const start = 1825030 + 365 * (year - 1) + Math.floor(year / 4);
    return (start + month * 30 + day - 1 - 2440588) * DAY;
  }
  // Orthodox Easter: Julian computus, converted to the Gregorian calendar (valid 1900–2099)
  function easter(y) {
    const a = y % 4, b = y % 7, c = y % 19;
    const d = (19 * c + 15) % 30, e = (2 * a + 4 * b - d + 34) % 7;
    const month = Math.floor((d + e + 114) / 31), day = ((d + e + 114) % 31) + 1;
    return utc(y, month, day) + 13 * DAY;
  }

  // Fixed feasts by Coptic date: [month index, day, name, kind]
  const FIXED = [
    [0, 1,   N('Nayrouz, the Coptic New Year', 'عيد النيروز، رأس السنة القبطية'), 'feast'],
    [0, 17,  N('Feast of the Holy Cross', 'عيد الصليب المجيد'), 'feast'],
    [2, 12,  N('Feast of Archangel Michael', 'عيد رئيس الملائكة ميخائيل'), 'saint'],
    [2, 29,  N('Feast of St. Peter, Seal of the Martyrs, our patron', 'عيد البابا بطرس خاتم الشهداء، شفيع كنيستنا'), 'patron'],
    [5, 8,   N('Presentation of the Lord in the Temple', 'دخول السيد المسيح الهيكل'), 'feast'],
    [6, 10,  N('Feast of the Holy Cross', 'عيد الصليب المجيد'), 'feast'],
    [6, 29,  N('Feast of the Annunciation', 'عيد البشارة'), 'major'],
    [8, 24,  N('Entry of the Lord into Egypt', 'دخول السيد المسيح أرض مصر'), 'feast'],
    [9, 12,  N('Feast of Archangel Michael', 'عيد رئيس الملائكة ميخائيل'), 'saint'],
    [10, 5,  N('Feast of Sts. Peter and Paul', 'عيد الرسولين بطرس وبولس'), 'major'],
    [11, 13, N('Feast of the Transfiguration', 'عيد التجلي'), 'feast'],
    [11, 16, N('Assumption of St. Mary', 'عيد صعود جسد السيدة العذراء'), 'feast'],
  ];

  // The rules for one day. dn = day number of a local calendar date.
  function day(dn) {
    const t = dn * DAY, g = new Date(t), y = g.getUTCFullYear(), dow = g.getUTCDay();
    const c = coptic(t);
    const rel = dn - dayNum(easter(y));
    const nat = dayNum(utc(y, 1, 7));                       // this year's Nativity
    const nextNat = dayNum(utc(y + 1, 1, 7));
    const apostlesEnd = dayNum(fromCoptic(coptic(utc(y, 7, 1)).year, 10, 4));   // Abib 4

    let feast = null, kind = null, season = null, fastSeason = false, fast = false, noWedFri = false;
    const setSeason = (name, isFast) => { season = name; fastSeason = isFast; if (isFast) fast = true; };

    if (rel >= -69 && rel <= -67) setSeason(N("Jonah's Fast", 'صوم يونان'), true);
    if (rel === -66) { feast = N("Jonah's Passover", 'فصح يونان'); kind = 'feast'; }
    if (rel >= -55 && rel <= -8) setSeason(N('Great Lent', 'الصوم الكبير'), true);
    if (rel === -8) { feast = N('Lazarus Saturday', 'سبت لعازر'); kind = 'feast'; }
    if (rel === -7) { feast = N('Palm Sunday', 'أحد الشعانين'); kind = 'major'; setSeason(N('Holy Week', 'أسبوع الآلام'), true); }
    if (rel >= -6 && rel <= -1) {
      setSeason(N('Holy Week', 'أسبوع الآلام'), true);
      if (rel === -3) { feast = N('Covenant Thursday', 'خميس العهد'); kind = 'holy'; }
      if (rel === -2) { feast = N('Good Friday', 'الجمعة العظيمة'); kind = 'holy'; }
      if (rel === -1) { feast = N('Bright Saturday', 'سبت النور'); kind = 'holy'; }
    }
    if (rel === 0) { feast = N('Feast of the Resurrection', 'عيد القيامة المجيد'); kind = 'major'; }
    if (rel >= 1 && rel <= 49) { setSeason(N('The Holy Fifty Days', 'الخماسين المقدسة'), false); noWedFri = true; }
    if (rel === 7) { feast = N('Thomas Sunday', 'أحد توما'); kind = 'feast'; }
    if (rel === 39) { feast = N('Feast of the Ascension', 'عيد الصعود'); kind = 'major'; }
    if (rel === 49) { feast = N('Feast of Pentecost', 'عيد العنصرة'); kind = 'major'; }
    if (rel >= 50 && dn <= apostlesEnd) setSeason(N("The Apostles' Fast", 'صوم الرسل'), true);
    if (c.month === 11 && c.day <= 15) setSeason(N("St. Mary's Fast", 'صوم السيدة العذراء'), true);
    if (dn >= nextNat - 43 && dn <= nextNat - 1) setSeason(N('The Nativity Fast', 'صوم الميلاد'), true);
    if (dn <= nat - 1 && dn >= nat - 43) setSeason(N('The Nativity Fast', 'صوم الميلاد'), true);
    if (dn === nat) { feast = N('Feast of the Nativity', 'عيد الميلاد المجيد'); kind = 'major'; }
    if (dn === nat + 7) { feast = N('Feast of the Circumcision', 'عيد الختان'); kind = 'feast'; }
    if (dn === nat + 11) { feast = N('Paramoun of Theophany', 'برامون الغطاس'); kind = 'feast'; fast = true; }
    if (dn === nat + 12) { feast = N('Feast of Theophany', 'عيد الغطاس المجيد'); kind = 'major'; }
    if (dn === nat + 14) { feast = N('Wedding at Cana of Galilee', 'عرس قانا الجليل'); kind = 'feast'; }
    if (dn >= nat && dn <= nat + 12 && dn !== nat + 11) noWedFri = true;   // between Nativity and Theophany
    if (c.month === 3 && !season) setSeason(N('The month of Kiahk', 'شهر كيهك'), false);

    if (!feast) for (const [m, d, name, k] of FIXED) {
      if (c.month === m && c.day === d) {
        feast = name;
        // A fixed feast inside Great Lent or Holy Week is kept without breaking the fast
        kind = (k === 'major' && fastSeason && (rel >= -55 && rel <= -1)) ? 'feast' : k;
      }
    }
    if ((dow === 3 || dow === 5) && !noWedFri) fast = true;          // Wednesdays and Fridays
    if (kind === 'major' && rel !== -7) fast = false;                // no fasting on major feasts (except Palm Sunday)

    return { dn, coptic: c, feast, kind, season, fastSeason, fast };
  }

  function info(date) {
    const now = date || new Date();
    const dn = dayNum(utc(now.getFullYear(), now.getMonth() + 1, now.getDate()));
    const today = day(dn);
    // What's coming up: the next feast, or the start of a fasting season, within 60 days
    let next = null, prev = today;
    for (let i = 1; i <= 60 && !next; i++) {
      const d = day(dn + i);
      if (d.fastSeason && (!prev.fastSeason || prev.season.en !== d.season.en))
        next = { name: d.season, days: i, begins: true };
      else if (d.feast && ['major', 'feast', 'patron'].includes(d.kind)) next = { name: d.feast, days: i };
      prev = d;
    }
    if (next) next.date = new Date(now.getFullYear(), now.getMonth(), now.getDate() + next.days);
    const [folder, suffix] = SYNAX[today.coptic.month];
    return Object.assign(today, {
      next,
      synaxariumUrl: `https://st-takla.org/books/en/church/synaxarium/${folder}/${String(today.coptic.day).padStart(2, '0')}-${suffix}.html`,
      monthName: lang => MONTHS[lang][today.coptic.month]
    });
  }

  root.ChurchCalendar = { info, day, coptic, easter, fromCoptic, MONTHS };
})(typeof window !== 'undefined' ? window : globalThis);
