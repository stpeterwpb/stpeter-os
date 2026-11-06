// St. Peter OS — home screen settings.
// Edit this file to change what shows on the TV, then press F12 (or restart) to reload.
// Fields ending in _ar are the Arabic versions.

window.STPETER = {
  churchName:        "St. Peter, Seal of the Martyrs",
  churchSubtitle:    "Coptic Orthodox Church",
  churchName_ar:     "كنيسة القديس بطرس خاتم الشهداء",
  churchSubtitle_ar: "القبطية الأرثوذكسية",

  // Each classroom's name and AirPlay code are set by the St. Peter installer (in room.js).

  // Ask which language to use every time the TV is turned on.
  askLanguageAtStartup: true,

  // Tiles on the home screen, in order. Change, remove, or add freely (up to 6). Keep it short: fewer tiles is easier.
  // icon: one of "airplay", "reader", "desktop", "board", "play", "hymns", "church", "live"
  tiles: [
    { title: "AirPlay",       title_ar: "AirPlay",
      subtitle: "Share from iPhone or Mac", subtitle_ar: "اعرض من الآيفون أو الماك",
      icon: "airplay", action: "airplay" },
    { title: "Coptic Reader", title_ar: "القارئ القبطي",
      subtitle: "Readings and liturgies", subtitle_ar: "القراءات والقداسات",
      icon: "reader", action: "copticreader" },
    { title: "Desktop",       title_ar: "سطح المكتب",
      subtitle: "PowerPoint and more", subtitle_ar: "باوربوينت وغيره",
      icon: "desktop", action: "windows" },
    { title: "Whiteboard",    title_ar: "السبورة",
      subtitle: "Draw and write", subtitle_ar: "ارسم واكتب",
      icon: "board", url: "whiteboard.html" },
    { title: "YouTube",       title_ar: "يوتيوب",
      subtitle: "Without ads", subtitle_ar: "من غير إعلانات",
      icon: "play", url: "https://www.youtube.com" }
  ]
};
