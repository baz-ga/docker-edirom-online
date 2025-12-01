# docker-Edirom-Online

A Docker image running on [eXist-db](https://www.exist-db.org/) with a predeployed [Edirom Online](https://github.com/Edirom/Edirom-Online), and options for deploying additional XAR archives on-build or on-run.

This Docker image is a multi-stage Docker image and has the following stages:

* STAGE 1: **xar-fetcher**

  The *xar-fetcher* stage is based on *bwbohl/sencha-cmd:2.1.0* and uses multiple strategies to obtain the EXPath Packages resp. XAR archives that are to be deployed to *STAGE 2*. One of which allows to inject local XAR archives (cf. [Building the Docker Image](#building-the-docker-image)).

* STAGE 2: **edirom-online**

  The *edirom-online* stage is based on *stadlerpeter/existdb:6.4.0*, which runs an eXist database. *STAGE 2* copies XAR archives fetched by *STAGE 1* and places them into the `autodeploy` directory of the eXist database. Moreover, it provides a method for deploying additional XAR archives to the eXist-database when running the Docker image for the first time (cf. [Running the Docker Image](#running-the-docker-image)).

## Pulling the Docker Image

<!--TODO describe how to pull -->

## Running the Docker Image

> [!NOTE]
> ```bash
> docker run -p 8080:8080 -v `pwd`/add-xars:/var/add-xars ghcr.io/bwbohl/docker-edirom-online
> ```

If you just want to run the Docker image and start using eXist-db with an installed Edirom Online, e.g., run:

```bash
docker run -p 8080:8080 ghcr.io/bwbohl/docker-edirom-online
```

If you want to deploy additional XAR archives to the eXist database when running the Docker image for the first time, you can use the docker `-v` flag to mount a local directory to the Docker image's `/var/add-xars` directory, e.g. by running:

```bash
docker run -p 8080:8080 -v `pwd`/add-xars:/var/add-xars ghcr.io/bwbohl/docker-edirom-online
```

Any XAR archive contained in your local directory will be copied to the autodeploy directory of the eXist database and thus deployed on first run.

> [!IMPORTANT]
> Deploying additional XAR archives to eXist-db will only work when starting the database for the first time!

### Environment Variables

As the final stage of the Docker image is based on stadlerpeter/existdb:6.4.0, all environment variables defined for it are valid run arguments for the Docker image.

For an overview please visit the [corresponding documentation](https://github.com/peterstadler/existdb-docker/blob/69678f7f61e0d2f5a6dcf2993568dbdbd01f897b/README.md)

This Docker image overrides the following environment variables if not set to other values in the `docker run` command:

* **EXIST_DEFAULT_APP_PATH**

  Is being set to `xmldb:exist:///db/apps/Edirom-Online` make Edirom Online the default app.

* **EXIST_CONTEXT_PATH**

  Is being set to `/` in order ro make Edirom Online available at the root of the configured host and port.

* **EXIST_ENV**

  Is being set to `development`.


## Building the Docker Image

> [!WARNING] Building this Docker image requires a *GitHub API Token* for fetching the Edirom XAR archives.

The GitHub API Token should be stored in a simple textfile, e.g., called `MY_GITHUB_API_TOKEN`, in the form:

```txt
GITHUB_API_TOKEN=ghp_************************
```

When issuing the build you should provide this file using the `--secret`option, as in the following example:

```bash
docker build -t ghcr.io/bwbohl/docker-edirom-online:mytag --secret type=file,id=GITHUB_API_TOKEN,src=/PATH/TO/MY/SECRET/MY_GITHUB_API_TOKEN .
```

> [!IMPORTANT]
> If you want to include additional XAR archives when building the image simply place them in the `add-xars` directory next to the Docker file. These files will get copied by the *xar-fetcher* stage and handed to the *edirom-online* stage which will place them in the eXist-db `autodeploy` directory!

### Controlling the Deployed Edirom-Online Version

The *xar-fetcher* stage uses the [xar-fetcher-entrypoint.sh](xar-fetcher-entrypoint.sh) to determine how to obtain the [*Edirom Online*](https://github.com/Edirom/Edirom-Online) XAR archives. This depends from several build arguments:

* **EDIROM_VERSION_STRATEGY**

  The version strategy for the fetching the Edirom Online XAR archives. (default: 1.0.0).

  The build differentiates between values greater or equal to `2.0.0` and values less than `2.0.0` and applies different strategies:

    * < 2.0.0: download a monolithic Edirom Online including both, frontend and backend. The assumed repository name is `Edirom-Online`.

    * &gt;= 2.0.0: download separate Edirom Online frontend and Edirom Online backend. The assumed repository names are `Edirom-Online-Frontend` and `Edirom-Online-Backend`.

* **EDIROM_OWNER**

  The owner (organisation or user) of the `Edirom-Online` or `Edirom-Online-Frontend` and `Edirom-Online-Backend` repositories on GitHub (default: "Edirom").

* **EDIROM_REF**

  The git reference (branch or tag) to use for fetching the Edirom Online XAR archives (default: v${EDIROM_VERSION_STRATEGY}).

  If the reference is a tag the build assumes a tagged release and downoads any XAR archive (.xar) from the release assets.

  If the reference is a tag the build will checkout the branch and run try to run a `build.sh` in the root of the branch to create a XAR archive.


### Other Build Arguments (ARGs)

* **EDIROM_COMMIT**

  The Git commit hash of the Edirom Online version (default: "unknown"). This is relvant for the metadata of the final Docker image. When the image is built using the [build.sh](build.sh) in this repository, the git SHA of the installed Edirom XAR will be determined automatically.

* **BUILD_DATE**
  The date when the Docker image was built (default: 1970-01-01T00:00:00Z).

### eXist-db Build Arguments

As the final stage of the Docker image is based on stadlerpeter/existdb:6.4.0, all build arguments defined for it are valid additional build arguments for the Docker image. For an overview please visit the [corresponding documentation](https://github.com/peterstadler/existdb-docker/blob/69678f7f61e0d2f5a6dcf2993568dbdbd01f897b/README.md).


# Licenses

This software is published under the terms of the _GNU General Public License 3_ ([GPLv3](LICENSE-GPLv3.md)).

## Component Licenses

### Stage 1 (xar-fetcher)

- Base image: [bwbohl/sencha-cmd](https://github.com/bwbohl/sencha-cmd) - GPLv3
- [baz-ga/gh-asset-downloader](https://github.com/baz-ga/gh-asset-downloader) - GPLv3

### Stage 2 (edirom-online)

- Base image: [stadlerpeter/existdb](https://github.com/peterstadler/existdb-docker) - MIT License
  - Based on: [eclipse-temurin:17-jre](https://hub.docker.com/_/eclipse-temurin) - Apache License 2.0
  - Includes: OpenJDK - GPLv2 with Classpath Exception
    - See [DockerHub](https://hub.docker.com/_/eclipse-temurin) for additional license information
- [eXist-db](https://github.com/exist-db/exist) - LGPL-2.1
- [Edirom Online](https://github.com/Edirom/Edirom-Online) - GPLv3

## Additional Software

The referenced Docker images may contain additional software under various licenses.

## User Responsibility

It is the responsibility of the user of any pre-built image to ensure that any use complies with all relevant licenses for all software contained within.


# Acknowledgements

  This Docker image was developed in the context of the *Bernd Alois Zimmermann-Gesamtausgabe* project (BAZ-GA).

  The *Bernd Alois Zimmermann-Gesamtausgabe. Historisch-kritische Ausgabe seiner Werke, Schriften und Briefe* (*Bernd Alois Zimmermann Complete Edition. Historical-Critical Edition of his Works, Writings, and Letters*) are promoted by the Union of the German Academies of Sciences and Humanities, represented by the Academy of Sciences and Humanities Berlin-Brandenburg and the Academy of Sciences and Literature | Mainz, funded by the Federal Ministry of Education and Research, Bonn and Berlin, the Berlin Senate Department for Higher Education and Research, Health and Long-Term Care and the Hessian Ministry of Science and the Arts, Wiesbaden.
  
  For more information please visit: https://www.zimmermann-gesamtausgabe.de.
