<?xml version="1.0" encoding="UTF-8"?>
<!-- copied from http://saxonica.com/ce/user-doc/1.1/index.html#!starting/running/pi-sample -->
<!-- and then tweaked. -->
<xsl:transform version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
  <xsl:output method="html" indent="no"/>

  <xsl:template match="/"> 
    <html>
      <head>
        <title>tapasBoot</title>
        <meta http-equiv="Content-Type" content="text/html" />
        <script type="text/javascript" language="javascript"
          src="../Saxonce/Saxonce.nocache.js"/>        
        <script>
          var onSaxonLoad = function() {
          Saxon.run( {
          source:     location.href,
          logLevel:   "SEVERE",
          stylesheet: "tapasEngine.xslt"
          });
          }
        </script>
      </head>
      <body>
        <p><!-- I am valid, hear me roar! --></p>
      </body>
    </html>
  </xsl:template>
  
</xsl:transform>