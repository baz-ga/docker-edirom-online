xquery version "3.1";

(: Resolve the backend's actual installation target from the package registry.
   Falls back to BACKEND_URL env var, then to the conventional default. :)
let $registered-target :=
    collection("/db/system/repo")//target[../abbrev = "Edirom-Online-Backend"]/string()
let $backendURL :=
    if (normalize-space($registered-target) != "") then
        "../" || $registered-target || "/"
    else
        (environment-variable("BACKEND_URL"), "../Edirom-Online-Backend/")[normalize-space(.) != ""][1]

let $fe-collection := "/db/apps/Edirom-Online-Frontend"
let $config := '{"backendURL": "' || $backendURL || '"}'

return (
    if (not(xmldb:collection-available($fe-collection))) then
        xmldb:create-collection("/db/apps", "Edirom-Online-Frontend")
    else (),
    xmldb:store($fe-collection, "config.json", $config, "application/json")
)
