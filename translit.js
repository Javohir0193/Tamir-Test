// Ta'mir: ўзбекча кирилл → лотин (window.cyr2lat). lang.js ва admin-i18n.js «LAT» тили учун ишлатади.
// Қоидалар: е → ye (сўз бошида, унлидан ва ъ/ь дан кейин), ц → ts (унлидан кейин) ёки s, ъ → ʼ, ь → тушиб қолади.
// Катта ҳарф: «Ш» кейинги ҳарф кичик бўлса «Sh», бутун сўз катта бўлса «SH».
(function () {
  "use strict";
  var MAP = {
    "а":"a", "б":"b", "в":"v", "г":"g", "д":"d", "ё":"yo", "ж":"j", "з":"z", "и":"i", "й":"y", "к":"k", "л":"l",
    "м":"m", "н":"n", "о":"o", "п":"p", "р":"r", "с":"s", "т":"t", "у":"u", "ф":"f", "х":"x", "ч":"ch", "ш":"sh",
    "щ":"sh", "ъ":"ʼ", "ы":"i", "ь":"", "э":"e", "ю":"yu", "я":"ya", "ў":"oʻ", "қ":"q", "ғ":"gʻ", "ҳ":"h"
  };
  var VOWEL = /[аеёиоуэюяўАЕЁИОУЭЮЯЎ]/, SIGN = /[ъьЪЬ]/, LETTER = /[A-Za-zА-Яа-яЁёЎўҚқҒғҲҳ]/, UPPER = /[A-ZА-ЯЁЎҚҒҲ]/, LOWER = /[a-zа-яёўқғҳ]/;
  var HAS = /[А-Яа-яЁёЎўҚқҒғҲҳ]/;

  function base(ch, prev) {
    var lc = ch.toLowerCase();
    if (lc === "е") return (!prev || !LETTER.test(prev) || VOWEL.test(prev) || SIGN.test(prev)) ? "ye" : "e";
    if (lc === "ц") return (prev && VOWEL.test(prev)) ? "ts" : "s";
    return MAP[lc];
  }

  function cyr2lat(s) {
    s = String(s == null ? "" : s);
    if (!HAS.test(s)) return s;
    var out = "";
    for (var i = 0; i < s.length; i++) {
      var ch = s.charAt(i), prev = i > 0 ? s.charAt(i - 1) : "", next = s.charAt(i + 1);
      var lat = base(ch, prev);
      if (lat === undefined) { out += ch; continue; }
      if (lat && UPPER.test(ch)) {
        // кейинги ёки олдинги ҳарф ҳам катта бўлса, бутун сўз катта деб ҳисоблаймиз
        var caps = (next && UPPER.test(next)) || (!LOWER.test(next || "") && prev && UPPER.test(prev));
        lat = caps ? lat.toUpperCase() : lat.charAt(0).toUpperCase() + lat.slice(1);
      }
      out += lat;
    }
    return out;
  }

  window.cyr2lat = cyr2lat;
})();
