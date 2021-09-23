set grass=%1
set python=%OSGEO4W_ROOT%/bin/python3

call %grass% --tmp-location XY --exec g.extension extension=g.download.location
