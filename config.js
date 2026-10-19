// Ta'mir — қайси база билан ишлаш. Сайт манзилига қараб танланади:
// асосий сайт → асосий база, синов сайти → синов базаси. Кодни ўзгартириш шарт эмас.
// Бу ердаги калитлар ОЧИҚ (publishable) калитлар — уларни сайтга қўйиш хавфсиз. Махфий (secret) калитни бу ерга ҲЕЧ ҚАЧОН ёзманг.
(function () {
  var ENVS = {
    prod: { supabaseUrl: "https://agajmytkjpkihvaurqij.supabase.co", supabaseKey: "sb_publishable_vRb_dyiYUyPWNE9sIpDt8A_OM-64Nfi" },
    test: { supabaseUrl: "https://mlhhmohaxpetptmrtqrz.supabase.co", supabaseKey: "sb_publishable_J25T7bWC4ITRQ8NAZUg0sg_k_jys38i" }   // синов лойиҳаси: Project URL ва publishable key
  };
  var TEST_HOSTS = ["tamir-test.netlify.app"];                             // масалан: ["tamir-test.netlify.app"]
  var h = location.hostname, env = TEST_HOSTS.indexOf(h) >= 0 || /(^|\.)tamir-test/i.test(h) || /\/tamir-test(\/|$)/i.test(location.pathname) ? "test" : "prod";
  var c = ENVS[env]; c.env = env; c.botApi = c.supabaseUrl ? c.supabaseUrl + "/functions/v1/tg-bot" : "";
  window.TAMIR_CONFIG = c;
})();
