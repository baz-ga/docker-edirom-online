<!--
# -----------------------------------------------------------------------------
# This file is part of <https://github.com/baz-ga/docker-edirom-online>
# Version: 1.0.0
# Date: 2025-07-11
# Authors: Benjamin W. Bohl <https://github.com/bwbohl>
# Publisher: Bernd Alois Zimmermann-Gesamtausgabe <https://github.com/baz-ga>
# License: MIT
# DOI: []
# -----------------------------------------------------------------------------
# This Dockerimage was developed in the context of the
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
# -----------------------------------------------------------------------------
# For more information please visit: https://www.zimmermann-gesamtausgabe.de.
# -----------------------------------------------------------------------------
-->

# add-xars directory in docker-edirom-online

Before running your copy of the container make sure to place your XAR packages containing your Edirom editions in this folder. On launch they will be copied to the autodeploy folder of eXist-db and then deployed to the database.
