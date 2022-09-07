defmodule WebbkollWeb.Plugs.Locale do
  # Some code/inspiration from
  # http://code.parent.co/practical-i18n-with-phoenix-and-elixir/
  import Plug.Conn
  @locales Map.keys(Application.compile_env(:webbkoll, :locales))

  def init(default), do: default

  def call(%Plug.Conn{params: %{"locale" => loc}} = conn, _default) when loc in @locales do
    Gettext.put_locale(WebbkollWeb.Gettext, loc)
    assign(conn, :locale, loc)
  end

  def call(conn, default) do
    locale_to_use =
      conn
      |> extract_accept_language()
      |> Enum.find(nil, fn accepted_locale -> Enum.member?(@locales, accepted_locale) end)
      |> case do
        nil -> default
        lang -> lang
      end

    path =
      if conn.params["locale"] != nil and String.downcase(conn.params["locale"]) in ietf_codes() do
        ~r/(\/)#{conn.params["locale"]}(\/(?:.+)?|\?(?:.+)?|$)/
        |> Regex.replace(conn.request_path, "\\1#{locale_to_use}\\2")
      else
        "/#{locale_to_use}#{conn.request_path}"
      end

    path =
      if conn.query_string == "" do
        path
      else
        path <> "?#{conn.query_string}"
      end

    # If user hits / and preferred browser language isn't supported, don't
    # redirect to /en/ - just show the English page on /. If we redirect to
    # /en/ by default then that's what many links/bookmarks will point to,
    # making it harder for users to discover when we DO have a relevant
    # translation, as we also don't want to force another language on a user
    # who's fetching an URL with a language explicitly set (such as /en/).
    if conn.request_path == "/" and path == "/en/" do
      Gettext.put_locale(WebbkollWeb.Gettext, "en")
      assign(conn, :locale, "en")
    else
      Phoenix.Controller.redirect(conn, to: path) |> halt
    end
  end

  # extract_accept_language(), parse_language_option() and ensure_language_fallbacks()
  # are from https://github.com/smeevil/set_locale by smeevil, WTFPL v2
  def extract_accept_language(conn) do
    case Plug.Conn.get_req_header(conn, "accept-language") do
      [value | _] ->
        value
        |> String.split(",")
        |> Enum.map(&parse_language_option/1)
        |> Enum.sort(&(&1.quality > &2.quality))
        |> Enum.map(& &1.tag)
        |> Enum.reject(&is_nil/1)
        |> ensure_language_fallbacks()

      _ ->
        []
    end
  end

  defp parse_language_option(string) do
    captures = Regex.named_captures(~r/^\s?(?<tag>[\w\-]+)(?:;q=(?<quality>[\d\.]+))?$/i, string)

    quality =
      case Float.parse(captures["quality"] || "1.0") do
        {val, _} -> val
        _ -> 1.0
      end

    %{tag: captures["tag"], quality: quality}
  end

  defp ensure_language_fallbacks(tags) do
    Enum.flat_map(tags, fn tag ->
      [language | _] = String.split(tag, "-")
      if Enum.member?(tags, language), do: [tag], else: [tag, language]
    end)
  end

  defp ietf_codes do
    ~w(af af-na af-za agq agq-cm ak ak-gh am am-et ar ar-001 ar-ae ar-bh ar-dj ar-dz ar-eg ar-eh ar-er ar-il ar-iq ar-jo ar-km ar-kw ar-lb ar-ly ar-ma ar-mr ar-om ar-ps ar-qa ar-sa ar-sd ar-so ar-ss ar-sy ar-td ar-tn ar-ye as as-in asa asa-tz ast ast-es az az-cyrl az-cyrl-az az-latn az-latn-az bas bas-cm be be-by bem bem-zm bez bez-tz bg bg-bg bm bm-latn bm-latn-ml bn bn-bd bn-in bo bo-cn bo-in br br-fr brx brx-in bs bs-cyrl bs-cyrl-ba bs-latn bs-latn-ba ca ca-ad ca-es ca-es-valencia ca-fr ca-it cgg cgg-ug chr chr-us cs cs-cz cy cy-gb da da-dk da-gl dav dav-ke de de-at de-be de-ch de-de de-li de-lu dje dje-ne dsb dsb-de dua dua-cm dyo dyo-sn dz dz-bt ebu ebu-ke ee ee-gh ee-tg el el-cy el-gr en en-001 en-150 en-ag en-ai en-as en-au en-bb en-be en-bm en-bs en-bw en-bz en-ca en-cc en-ck en-cm en-cx en-dg en-dm en-er en-fj en-fk en-fm en-gb en-gd en-gg en-gh en-gi en-gm en-gu en-gy en-hk en-ie en-im en-in en-io en-je en-jm en-ke en-ki en-kn en-ky en-lc en-lr en-ls en-mg en-mh en-mo en-mp en-ms en-mt en-mu en-mw en-my en-na en-nf en-ng en-nr en-nu en-nz en-pg en-ph en-pk en-pn en-pr en-pw en-rw en-sb en-sc en-sd en-sg en-sh en-sl en-ss en-sx en-sz en-tc en-tk en-to en-tt en-tv en-tz en-ug en-um en-us en-us-posix en-vc en-vg en-vi en-vu en-ws en-za en-zm en-zw eo eo-001 es es-419 es-ar es-bo es-cl es-co es-cr es-cu es-do es-ea es-ec es-es es-gq es-gt es-hn es-ic es-mx es-ni es-pa es-pe es-ph es-pr es-py es-sv es-us es-uy es-ve et et-ee eu eu-es ewo ewo-cm fa fa-af fa-ir ff ff-cm ff-gn ff-mr ff-sn fi fi-fi fil fil-ph fo fo-fo fr fr-be fr-bf fr-bi fr-bj fr-bl fr-ca fr-cd fr-cf fr-cg fr-ch fr-ci fr-cm fr-dj fr-dz fr-fr fr-ga fr-gf fr-gn fr-gp fr-gq fr-ht fr-km fr-lu fr-ma fr-mc fr-mf fr-mg fr-ml fr-mq fr-mr fr-mu fr-nc fr-ne fr-pf fr-pm fr-re fr-rw fr-sc fr-sn fr-sy fr-td fr-tg fr-tn fr-vu fr-wf fr-yt fur fur-it fy fy-nl ga ga-ie gd gd-gb gl gl-es gsw gsw-ch gsw-fr gsw-li gu gu-in guz guz-ke gv gv-im ha ha-latn ha-latn-gh ha-latn-ne ha-latn-ng haw haw-us he he-il hi hi-in hr hr-ba hr-hr hsb hsb-de hu hu-hu hy hy-am id id-id ig ig-ng ii ii-cn is is-is it it-ch it-it it-sm ja ja-jp jgo jgo-cm jmc jmc-tz ka ka-ge kab kab-dz kam kam-ke kde kde-tz kea kea-cv khq khq-ml ki ki-ke kk kk-cyrl kk-cyrl-kz kkj kkj-cm kl kl-gl kln kln-ke km km-kh kn kn-in ko ko-kp ko-kr kok kok-in ks ks-arab ks-arab-in ksb ksb-tz ksf ksf-cm ksh ksh-de kw kw-gb ky ky-cyrl ky-cyrl-kg lag lag-tz lb lb-lu lg lg-ug lkt lkt-us ln ln-ao ln-cd ln-cf ln-cg lo lo-la lt lt-lt lu lu-cd luo luo-ke luy luy-ke lv lv-lv mas mas-ke mas-tz mer mer-ke mfe mfe-mu mg mg-mg mgh mgh-mz mgo mgo-cm mk mk-mk ml ml-in mn mn-cyrl mn-cyrl-mn mr mr-in ms ms-latn ms-latn-bn ms-latn-my ms-latn-sg mt mt-mt mua mua-cm my my-mm naq naq-na nb nb-no nb-sj nd nd-zw ne ne-in ne-np nl nl-aw nl-be nl-bq nl-cw nl-nl nl-sr nl-sx nmg nmg-cm nn nn-no nnh nnh-cm nus nus-sd nyn nyn-ug om om-et om-ke or or-in os os-ge os-ru pa pa-arab pa-arab-pk pa-guru pa-guru-in pl pl-pl ps ps-af pt pt-ao pt-br pt-cv pt-gw pt-mo pt-mz pt-pt pt-st pt-tl qu qu-bo qu-ec qu-pe rm rm-ch rn rn-bi ro ro-md ro-ro rof rof-tz root ru ru-by ru-kg ru-kz ru-md ru-ru ru-ua rw rw-rw rwk rwk-tz sah sah-ru saq saq-ke sbp sbp-tz se se-fi se-no se-se seh seh-mz ses ses-ml sg sg-cf shi shi-latn shi-latn-ma shi-tfng shi-tfng-ma si si-lk sk sk-sk sl sl-si smn smn-fi sn sn-zw so so-dj so-et so-ke so-so sq sq-al sq-mk sq-xk sr sr-cyrl sr-cyrl-ba sr-cyrl-me sr-cyrl-rs sr-cyrl-xk sr-latn sr-latn-ba sr-latn-me sr-latn-rs sr-latn-xk sv sv-ax sv-fi sv-se sw sw-cd sw-ke sw-tz sw-ug ta ta-in ta-lk ta-my ta-sg te te-in teo teo-ke teo-ug th th-th ti ti-er ti-et to to-to tr tr-cy tr-tr twq twq-ne tzm tzm-latn tzm-latn-ma ug ug-arab ug-arab-cn uk uk-ua ur ur-in ur-pk uz uz-arab uz-arab-af uz-cyrl uz-cyrl-uz uz-latn uz-latn-uz vai vai-latn vai-latn-lr vai-vaii vai-vaii-lr vi vi-vn vun vun-tz wae wae-ch xog xog-ug yav yav-cm yi yi-001 yo yo-bj yo-ng zgh zgh-ma zh zh-hans zh-hans-cn zh-hans-hk zh-hans-mo zh-hans-sg zh-hant zh-hant-hk zh-hant-mo zh-hant-tw zu zu-za)
  end
end
