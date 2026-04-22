xquery version "3.1";

declare namespace expath = "http://expath.org/ns/pkg";

(: Locate the frontend collection via the package registry :)
let $fe-collection :=
    let $descriptor :=
        collection(repo:get-root())//expath:package[@name = "http://www.edirom.de/apps/EdiromOnlineFrontend"]
    return
        util:collection-name($descriptor)

(: Locate the backend collection via the package registry :)
let $be-collection :=
    let $descriptor :=
        collection(repo:get-root())//expath:package[@name = "http://www.edirom.de/apps/EdiromOnlineBackend"]
    return
        util:collection-name($descriptor)

(: Derive a context-relative backendURL, e.g. /db/apps/Edirom-Online-Backend -> apps/Edirom-Online-Backend/
   Using repo:get-root() avoids hardcoding /db/ and works regardless of DEFAULT_APP_PATH.
   A relative URL works because frontend and backend share the same eXist context path. :)
let $repo-root := repo:get-root()

let $backendURL :=
    if (normalize-space($be-collection) != "") then
        substring-after($repo-root, "/db/") || substring-after($be-collection, $repo-root) || "/"
    else
        error(xs:QName("err:CONFIG"), "Edirom-Online-Backend collection not found in package registry")

let $config := '{"backendURL": "' || $backendURL || '"}'

return
    if (normalize-space($fe-collection) != "") then
        xmldb:store($fe-collection, "config.json", $config, "application/json")
    else
        error(xs:QName("err:CONFIG"), "Edirom-Online-Frontend collection not found in package registry")
