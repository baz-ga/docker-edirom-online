#!/bin/bash
# ------------------------------------------------------------------------------
# edirom-entrypoint.sh
# ------------------------------------------------------------------------------
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2025
# Berlin-Brandenburg Academy of Sciences and Humanities and
# the Academy of Sciences and Literature | Mainz
# ------------------------------------------------------------------------------
# This was developed as part of:
# docker-edirom-online <https://github.com/baz-ga/docker-edirom-online>
#
# Version: @SEMANTIC_VERSION@
# Date: @RELEASE-DATE@
# Authors: Benjamin W. Bohl <https://github.com/bwbohl>
# Publishers: Berlin-Brandenburg Academy of Sciences and Humanities and
#             the Academy of Sciences and Literature | Mainz
#             under the direction of Dörte Schmidt
# Distributor: Bernd Alois Zimmermann-Gesamtausgabe <https://github.com/baz-ga>
# DOI: @DOI@
#
# ------------------------------------------------------------------------------
# License: GNU General Public License v3.0
# ------------------------------------------------------------------------------
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# ---
# Note: Earlier versions of this project were MIT licensed.
# The license was changed to GPL v.3 for clarity and compatibility with
# software packaged in the Docker images.
#
# ------------------------------------------------------------------------------
# Acknowledgements
# ------------------------------------------------------------------------------
# This file was developed in the context of the
# Bernd Alois Zimmermann-Gesamtausgabe (BAZ-GA).
#
# The Bernd Alois Zimmermann-Gesamtausgabe. Historisch-kritische Ausgabe seiner
# Werke, Schriften und Briefe (Bernd Alois Zimmermann Complete Edition.
# Historical-Critical Edition of his Works, Writings, and Letters) are promoted
# by the Union of the German Academies of Sciences and Humanities, represented
# by the Academy of Sciences and Humanities Berlin-Brandenburg and the
# Academy of Sciences and Literature | Mainz, funded by the Federal Ministry of
# Education and Research, Bonn and Berlin, the Berlin Senate Department for
# Higher Education and Research, Health and Long-Term Care and the Hessian
# Ministry of Science and the Arts, Wiesbaden.
#
# For more information please visit: https://www.zimmermann-gesamtausgabe.de.
#
# ------------------------------------------------------------------------------

echo
echo "###################################"
echo "# Welcome to docker-edirom-online #"
echo "###################################"
echo
echo "This docker container is based on stadlerpeter/existdb:6."
echo "In order to deploy your data XARs for Edirom-Online place"
echo "them in ›add-xars‹ directory next to the Dockerfile."
echo
echo "copying additional XARs…"
cp /var/add-xars/*.xar $EXIST_HOME/autodeploy/
echo
# starting the original image's entrypoint
echo "starting base-image…"
echo
exec ${EXIST_HOME}/entrypoint.sh
