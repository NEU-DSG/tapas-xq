<?xml version="1.0" encoding="UTF-8"?>
<!-- Copyleft 2013 Syd Bauman -->
<!-- For complete copyright notice see near bottom of file. -->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:tapas="http://www.wheatoncollege.edu/TAPAS/1.0"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:tei="http://www.tei-c.org/ns/1.0" >

  <!-- Read in a random TEI (P5) file, and write out a TAPAS-friendly copy -->
  <!-- of the same, step 1: -->
  <!-- * insert new <tapas:metadata> element with pre-digested metadata -->
  <!-- * strip off paths from relative URLs -->
  <!-- * for elements that have data.pointer attrs, add a hashed version thereof -->

  <xsl:output method="xml" indent="yes"/>
  <!-- special chars -->
  <xsl:variable name="apos" select='"&apos;"'/>
  <!-- URL characters (per RFC 2396) that are not XML Name characters divided into three -->
  <!-- sets. Note that we think of colon (":") as a non-XML Name character. -->
  <xsl:variable name="URIc1" select="concat('!#$%&amp;', $apos )"/>
  <xsl:variable name="URIc2" select="'()*+,/'"/>
  <xsl:variable name="URIc3" select="':;=?@~'"/>
  
  
  <!-- ******************** -->
  <!-- main top-level stuff -->
  <!-- ******************** -->
  
  <!-- routine identity transform: copy everything not handled separately below -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- handle <TEI> element (note: <teiCorpus> may have been uppermost element, -->
  <!-- if so it would have been copied by identity) -->
  <xsl:template match="tei:TEI">
    <xsl:call-template name="insert-PIs"/>
    <!-- insert TAPAS metadata before <text>; this fails miserably if there -->
    <!-- is no <text>; or if there are nodes between multiple <text>s (which -->
    <!-- would be invalid TEI, only 1 <text> is allowed) -->
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="node()[following-sibling::tei:text]"/>
      <xsl:call-template name="tapasHeader"/>
      <xsl:apply-templates select="tei:text"/>
      <xsl:apply-templates select="node()[preceding-sibling::tei:text]"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template name="tapasHeader">
    <tapas_metadata>
      <xsl:call-template name="get-title"/>
      <xsl:call-template name="get-creator"/>
      <xsl:call-template name="get-contributor"/>
      <xsl:call-template name="get-date"/>
      <xsl:call-template name="get-language"/>
      <xsl:call-template name="get-rights"/>
      <xsl:call-template name="get-source"/>
      <!-- xsl:call-template name="get-subject"/ -->
      <xsl:call-template name="get-transforms"/>
    </tapas_metadata>
  </xsl:template>

  <!-- ******************** -->
  <!-- tapasHeader routines -->
  <!-- ******************** -->

  <xsl:template name="get-title">
    <xsl:for-each select="/*/tei:teiHeader/tei:fileDesc/tei:titleStmt[1]">
      <xsl:variable name="mainTitle_count" select="count( tei:title[@type='main'] )"/>
      <xsl:variable name="mainTitle1" select="normalize-space(tei:title[@type='main'][1])"/>
      <xsl:variable name="mainTitle1_len" select="string-length( $mainTitle1 )"/>
      <xsl:variable name="mainTitle1_last_8" select="substring( $mainTitle1, string-length($mainTitle1)-3 )"/>
      <xsl:variable name="mainTitle1_digitized" select="translate($mainTitle1,'0123456789','0000000000')"/>
      <xsl:variable name="got-title">
        <xsl:choose>
          <!-- first, check for WWP-style header info: -->
          <!-- * 1 <title type='main'> that ends w/ publication year to be stripped -->
          <xsl:when test="
            $mainTitle_count = 1
            and
            substring( $mainTitle1_digitized, $mainTitle1_len -20 ) = ', 0000 published 0000'">
            <xsl:value-of select="substring( $mainTitle1, 1, $mainTitle1_len -21)"/>
          </xsl:when>
          <xsl:when test="
            $mainTitle_count = 1
            and
            substring( $mainTitle1_digitized, $mainTitle1_len -8 ) = ', 0000-00'">
            <xsl:value-of select="substring( $mainTitle1, 1, $mainTitle1_len -9)"/>
          </xsl:when>
          <xsl:when test="
            $mainTitle_count = 1
            and
            substring( $mainTitle1_digitized, $mainTitle1_len -5 ) = ', 0000'">
            <xsl:value-of select="substring( $mainTitle1, 1, $mainTitle1_len -6)"/>
          </xsl:when>
          <!-- if there's a short or main title, take it -->
          <xsl:when test="tei:title[@short]">
            <xsl:value-of select="tei:title[@short][1]"/>
          </xsl:when>
          <xsl:when test="$mainTitle_count = 1">
            <xsl:value-of select="$mainTitle1"/>
          </xsl:when>
          <xsl:when test="$mainTitle_count > 1">
            <xsl:message>WARNING: more than one main title (<xsl:value-of select="$mainTitle_count"/> of 'em)</xsl:message>
            <xsl:apply-templates select="./tei:title[@type='main']"/>
          </xsl:when>
          <xsl:when test="count( tei:title ) > 1">
            <xsl:message>WARNING: using first title</xsl:message>
            <xsl:value-of select="tei:title[1]"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="tei:title"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:choose>
        <xsl:when test="position() = 1">
          <xsl:if test="normalize-space($got-title)">
            <dc_title><xsl:value-of select="normalize-space($got-title)"/></dc_title>
          </xsl:if>
        </xsl:when>
        <xsl:otherwise>
          <xsl:message>WARNING: only 1st ‹titleStmt› examined (this one, #<xsl:value-of select="position()"/>, ignored)</xsl:message>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:template name="get-creator">
    <xsl:variable name="got-creator">
      <xsl:choose>
        <xsl:when test="/*/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author">
          <xsl:value-of select="string(/*/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author[1])"/>
        </xsl:when>
        <xsl:when test="//tei:titlePage/tei:docAuthor">
          <xsl:value-of select="string(//tei:titlePage[1]/tei:docAuthor[1])"/>
        </xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="normalize-space($got-creator)">
      <dc_creator><xsl:value-of select="normalize-space($got-creator)"/></dc_creator>
    </xsl:if>
  </xsl:template>
  
  <xsl:template name="get-contributor">
    <xsl:for-each select="
          //tei:fileDesc/tei:titleStmt/tei:respStmt/*[not( self::tei:resp )]
        | //tei:fileDesc/tei:titleStmt/tei:sponsor
        | //tei:fileDesc/tei:titleStmt/tei:funder
        | //tei:fileDesc/tei:titleStmt/tei:principal
        | //tei:fileDesc/tei:titleStmt/tei:editor">
      <dc_contributor>
        <xsl:call-template name="extract-name">
          <xsl:with-param name="container" select="."/>
        </xsl:call-template>
        <xsl:variable name="resp">
          <xsl:choose>
            <xsl:when test="parent::tei:respStmt">
              <xsl:value-of select="normalize-space(parent::tei:respStmt/tei:resp)"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="local-name(.)"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:text> (</xsl:text>
        <xsl:value-of select="$resp"/>
        <xsl:text>)</xsl:text>
      </dc_contributor>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:template name="get-date">
    <xsl:variable name="got-date">
      <xsl:choose>
        <xsl:when test="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[@default='true']/tei:biblStruct[@default='true']/tei:analytic[1]/tei:date[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[@default='true']/tei:biblStruct[@default='true']/tei:analytic[1]/tei:date[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[@default='true']/tei:biblStruct[1]/tei:analytic[1]/tei:date[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[@default='true']/tei:biblStruct[1]/tei:analytic[1]/tei:date[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[1]/tei:biblStruct[@default='true']/tei:analytic[1]/tei:date[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[1]/tei:biblStruct[@default='true']/tei:analytic[1]/tei:date[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[1]/tei:biblStruct[1]/tei:analytic[1]/tei:date[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[1]/tei:biblStruct[1]/tei:analytic[1]/tei:date[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[@default='true']/tei:biblStruct[@default='true']/tei:monogr[1]/tei:imprint[1]/tei:date[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[@default='true']/tei:biblStruct[@default='true']/tei:monogr[1]/tei:imprint[1]/tei:date[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[@default='true']/tei:biblStruct[1]/tei:monogr[1]/tei:imprint[1]/tei:date[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[@default='true']/tei:biblStruct[1]/tei:monogr[1]/tei:imprint[1]/tei:date[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[1]/tei:biblStruct[1]/tei:monogr[1]/tei:imprint[1]/tei:date[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[1]/tei:biblStruct[1]/tei:monogr[1]/tei:imprint[1]/tei:date[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[@default='true']/tei:biblFull[@default='true']/tei:publicationStmt/tei:date[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[@default='true']/tei:biblFull[@default='true']/tei:publicationStmt/tei:date[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[@default='true']/tei:biblFull[1]/tei:publicationStmt/tei:date[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[@default='true']/tei:biblFull[1]/tei:publicationStmt/tei:date[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[1]/tei:biblFull[@default='true']/tei:publicationStmt/tei:date[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[1]/tei:biblFull[@default='true']/tei:publicationStmt/tei:date[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[1]/tei:biblFull[1]/tei:publicationStmt/tei:date[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[1]/tei:biblFull[1]/tei:publicationStmt/tei:date[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[@default='true']/tei:bibl[@default='true']/tei:date[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[@default='true']/tei:bibl[@default='true']/tei:date[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[@default='true']/tei:bibl[1]/tei:date[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[@default='true']/tei:bibl[1]/tei:date[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[1]/tei:bibl[@default='true']/tei:date[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[1]/tei:bibl[@default='true']/tei:date[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[1]/tei:bibl[1]/tei:date[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc[1]/tei:bibl[1]/tei:date[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="//tei:titlePage[1]/tei:docImprint[1]/tei:docDate[1]/tei:date[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="//tei:titlePage[1]/tei:docImprint[1]/tei:docDate[1]/tei:date[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="//tei:titlePage[1]/tei:docImprint[1]/tei:docDate[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="//tei:titlePage[1]/tei:docImprint[1]/tei:docDate[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="//tei:titlePage[1]/tei:docDate[1]/tei:date[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="//tei:titlePage[1]/tei:docDate[1]/tei:date[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="//tei:titlePage[1]/tei:docDate[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="//tei:titlePage[1]/tei:docDate[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="/*/tei:teiHeader/tei:fileDesc/tei:publicationStmt/tei:date[1]">
          <xsl:call-template name="extract-date">
            <xsl:with-param name="date-element" select="/*/tei:teiHeader/tei:fileDesc/tei:publicationStmt/tei:date[1]"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="normalize-space($got-date)">
      <dc_date><xsl:value-of select="normalize-space($got-date)"/></dc_date>
    </xsl:if>
  </xsl:template>
  
  <xsl:template name="get-language">
    <xsl:variable name="got-language">
      <xsl:choose>
        <xsl:when test="/tei:TEI/tei:text/ancestor-or-self::*/@xml:lang">
          <xsl:value-of select="/tei:TEI/tei:text/ancestor-or-self::*[@xml:lang][1]/@xml:lang"/>
        </xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="normalize-space($got-language)">
      <dc_language><xsl:value-of select="$got-language"/></dc_language>
    </xsl:if>
  </xsl:template>
  
  <xsl:template name="get-rights">
    <xsl:variable name="got-rights">
      <xsl:apply-templates mode="rights"
        select="/*/tei:teiHeader/tei:fileDesc/tei:publicationStmt">
       </xsl:apply-templates>
    </xsl:variable>
    <xsl:if test="normalize-space($got-rights)">
      <dc_rights><xsl:value-of select="normalize-space($got-rights)"/></dc_rights>
    </xsl:if>
  </xsl:template>
  
  <xsl:template name="get-source">
    <xsl:variable name="got-source">
      <xsl:apply-templates select="/*/tei:teiHeader/tei:fileDesc/tei:sourceDesc" mode="source"/>
    </xsl:variable>
    <xsl:if test="normalize-space($got-source)">
      <dc_source><xsl:value-of select="normalize-space($got-source)"/></dc_source>
    </xsl:if>
  </xsl:template>
  
  <xsl:template name="get-subject">
    <xsl:variable name="got-subject">
      <xsl:choose>
        <xsl:when test="/tei:TEI/tei:teiHeader/tei:profileDesc/tei:textClass/tei:classCode">
          <xsl:for-each select="/tei:TEI/tei:teiHeader/tei:profileDesc/tei:textClass/tei:classCode">
            <xsl:variable name="scheme" select="normalize-space(@scheme)"/>
            <xsl:variable name="me" select="normalize-space(.)"/>
            <xsl:choose>
              <xsl:when test="starts-with($scheme,'#')">
                <xsl:variable name="localScheme" select="substring-after($scheme,'#')"/>
                <xsl:choose>
                  <xsl:when test="//tei:category[@xml:id = $localScheme]">
                    <xsl:text>[</xsl:text>
                    <xsl:apply-templates select="//tei:category[@xml:id = $localScheme]"/>
                    <xsl:text>]:</xsl:text>
                    <xsl:apply-templates/>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="$scheme"/>
                    <xsl:text>:</xsl:text>
                    <xsl:apply-templates/>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>{</xsl:text>
                <xsl:value-of select="$scheme"/>
                <xsl:text>}:</xsl:text>
                <xsl:apply-templates/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:for-each>
        </xsl:when>
        <xsl:when test="/tei:TEI/tei:teiHeader/tei:profileDesc/tei:textClass/tei:catRef">
          <xsl:for-each select="/tei:TEI/tei:teiHeader/tei:profileDesc/tei:textClass/tei:catRef">
            <xsl:text>FIXME</xsl:text>
          </xsl:for-each>
        </xsl:when>
        <xsl:when test="/tei:TEI/tei:text/@ana">
          <xsl:value-of select="concat('FIXME:',/tei:TEI/tei:text/@ana)"/>
        </xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="normalize-space($got-subject)">
      <dc_subject><xsl:value-of select="$got-subject"/></dc_subject>
    </xsl:if>
  </xsl:template>
  
  <xsl:template name="get-transforms">
    <tapas:transforms>
      <tapas:transform name="TAPAS_Boilerplate"/>
      <tapas:transform name="TAPAS_Boilerplate_NoJS"/>
    </tapas:transforms>
  </xsl:template>
  
  <!-- *********************** -->
  <!-- tapasHeader subroutines -->
  <!-- *********************** -->
  
  <xsl:template name="extract-name">
    <xsl:param name="container"/>
    <xsl:choose>
      <xsl:when test="not($container/*)">
        <xsl:value-of select="normalize-space(.)"/>
      </xsl:when>
      <xsl:when test="count( $container/tei:name | $container/tei:orgName | $container/tei:persName ) = 1">
        <xsl:call-template name="extract-name">
          <xsl:with-param name="container" select="$container/tei:name | $container/tei:orgName | $container/tei:persName"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$container/tei:surname">
        <xsl:value-of select="normalize-space($container/tei:surname)"/>
        <xsl:if test="$container/tei:forename">
          <xsl:text>, </xsl:text>
          <xsl:choose>
            <xsl:when test="$container/tei:forename[@type='first']">
              <xsl:value-of select="normalize-space($container/tei:forename[@type='first'])"/>
              <xsl:for-each select="$container/tei:forename[@type='middle']">
                <xsl:value-of select="concat(' ',normalize-space(.))"/>
              </xsl:for-each>
              <!-- None of our test data has > 1 <forename type=first> or -->
              <!-- > 1 <forename type=middle>. -->
            </xsl:when>
            <xsl:otherwise>
              <xsl:variable name="forenames">
                <xsl:for-each select="$container/tei:forename">
                  <xsl:value-of select="concat( ' ', ., ' ' )"/>
                </xsl:for-each>
              </xsl:variable>
              <xsl:value-of select="normalize-space( $forenames )"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message>
          <xsl:text>WARNING: unable to figure out </xsl:text>
          <xsl:value-of select="local-name($container)"/>
          <xsl:text> with content '</xsl:text>
          <xsl:value-of select="normalize-space($container)"/>
          <xsl:text>'.</xsl:text>
        </xsl:message>
        <xsl:value-of select="normalize-space($container)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template name="extract-date">
    <xsl:param name="date-element"/>
    <xsl:variable name="extracted-date">
      <xsl:choose>
        <xsl:when test="$date-element/@when">
          <xsl:value-of select="$date-element/@when"/>
        </xsl:when>
        <xsl:when test="$date-element/@notBefore and $date-element/@notAfter">
          <xsl:value-of select="concat(
            'sometime between ',
            $date-element/@notBefore,
            ' and ',
            $date-element/@notAfter
            )"/>
        </xsl:when>
        <xsl:when test="$date-element/@from and $date-element/@to">
          <xsl:value-of select="concat(
            $date-element/@from,
            '&#x2013;',
            $date-element/@to
            )"/>
        </xsl:when>
        <xsl:when test="$date-element/@notAfter">
          <xsl:value-of select="concat(
            'sometime before ',
            $date-element/@notAfter
            )"/>
        </xsl:when>
        <xsl:when test="$date-element/@notBefore">
          <xsl:value-of select="concat(
            'sometime after ',
            $date-element/@notBefore
            )"/>
        </xsl:when>
        <xsl:when test="string-length( normalize-space( $date-element ) ) > 1">
          <xsl:value-of select="normalize-space( $date-element )"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:message>
            <xsl:text>WARNING: unable to figure a date from &lt;</xsl:text>
            <xsl:value-of select="local-name($date-element)"/>
            <xsl:for-each select="$date-element/@*">
              <xsl:value-of select="concat(
                ' ',
                name(.),
                '=',
                normalize-space(.)
                )"/>
            </xsl:for-each>
            <xsl:text>></xsl:text>
          </xsl:message>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="normalize-space($extracted-date)">
      <xsl:value-of select="$extracted-date"/>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="tei:publicationStmt" mode="rights">
    <xsl:apply-templates mode="rights"
      select="
       tei:p[
               contains( .,'opyright')
             or
               contains( .,'opyleft')
             or
               contains( .,'(c)')
             or
               contains( .,'&#xA9;')
             or
               contains( .,'ermission')
             or
               contains( .,'rights')
             or
               contains( .,'licen')
             or
               contains( .,'Licen')
             or
               contains( .,'odif')
            ]
     |tei:ab[
               contains( .,'opyright')
             or
               contains( .,'opyleft')
             or
               contains( .,'(c)')
             or
               contains( .,'&#xA9;')
             or
               contains( .,'ermission')
             or
               contains( .,'rights')
             or
               contains( .,'licen')
             or
               contains( .,'Licen')
             or
               contains( .,'odif')
            ]
      |tei:distributor
      |tei:authority
      |tei:idno
      |tei:availability
      |tei:address
      |tei:date
      |tei:publisher
      |tei:pubPlace"/>
  </xsl:template>
  <xsl:template mode="rights"
    match="tei:distributor|tei:authority|tei:idno|tei:address|tei:date|tei:publisher|tei:pubPlace"/>
  <xsl:template mode="rights"
    match="tei:ab|tei:p">
    <xsl:apply-templates mode="rights"/>
  </xsl:template>
  <xsl:template mode="rights"
    match="tei:availability">
    <xsl:choose>
      <xsl:when test="@status = 'free'  and  normalize-space(.) = ''">
        <xsl:text>freely available</xsl:text>
      </xsl:when>
      <xsl:when test="( @status = 'unknown' or not(@status) )  and  normalize-space(.) = ''">
        <xsl:text>copyright, availability, and licensing status of this document is unknown</xsl:text>
      </xsl:when>
      <xsl:when test="@status = 'restricted'  and  normalize-space(.) = ''">
        <xsl:text>apparently copyright</xsl:text>
        <xsl:choose>
          <xsl:when test="../tei:date">
            <xsl:text> </xsl:text>
            <xsl:call-template name="extract-date">
              <xsl:with-param name="date-element" select="../tei:date[1]"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>ed, details unknown</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test="@status = 'free'">
        <xsl:text>[Freely available.] </xsl:text>
        <xsl:apply-templates mode="rights"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates mode="rights"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="tei:license" mode="rights">
    <xsl:apply-templates select="node()"/>
    <xsl:if test="@target">
      <xsl:value-of select="concat(' [',@target,']')"/>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="comment()|*|processing-instruction()" mode="source">
    <xsl:apply-templates select="node()" mode="source"/>
  </xsl:template>
  <xsl:template match="text()" mode="source">
    <!-- return strings with any string of whitespace (including -->
    <!-- leading or trailing) reduced to a single blank -->
    <xsl:variable name="fake-delims" select="concat('|',.,'|')"/>
    <xsl:variable name="nsfd" select="normalize-space($fake-delims)"/>
    <xsl:value-of select="substring($nsfd,2,string-length($nsfd)-2)"/>
  </xsl:template>
  <xsl:template match="tei:title" mode="source">
    <xsl:text>&#x201C;</xsl:text>
    <xsl:apply-templates select="node()" mode="source"/>
    <xsl:text>&#x201D;</xsl:text>
  </xsl:template>

  <!-- *********** -->
  <!-- PI routines -->
  <!-- *********** -->
  
  <xsl:template match="processing-instruction()[
       name(.)='xml-model'
    or name(.)='oxygen'
    or name(.)='xml-stylesheet'
    ]">
    <xsl:variable name="name">
      <xsl:choose>
        <xsl:when test="starts-with(name(.),'xml')">
          <xsl:value-of select="concat('tapas',substring(name(.),4))"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat('tapas-',name(.))"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:processing-instruction name="{$name}">
      <xsl:value-of select="."/>
    </xsl:processing-instruction>
  </xsl:template>
  
  <xsl:template name="insert-PIs">
    <xsl:processing-instruction name="xml-stylesheet">
      <xsl:text>type="text/xsl" href="tapasBoot.xslt"</xsl:text>
    </xsl:processing-instruction>
  </xsl:template>
  
  <!-- ************************ -->
  <!-- data processing routines -->
  <!-- ************************ -->
  
  <xsl:template name="handle_ptrs" match="@target|@url|@ref|@corresp">
    <!-- Note: list of attrs matched should be extracted from -->
    <!-- schema or ODD. But I don't have time for that right -->
    <!-- now, so we just match those that show up in profiling -->
    <!-- data we received. -->
    <xsl:variable name="me" select="normalize-space(.)"/>
    <xsl:variable name="me_sans_path">
      <xsl:variable name="processed-URIs">
        <xsl:call-template name="process-first-URI">
          <xsl:with-param name="URIs" select="$me"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:value-of select="normalize-space($processed-URIs)"/>
    </xsl:variable>
    <xsl:attribute name="{name(.)}">
      <xsl:value-of select="$me_sans_path"/>
    </xsl:attribute>
    <xsl:attribute name="data-tapas-hashed-{local-name(.)}">
      <xsl:variable name="hashed-URIs">
        <xsl:call-template name="hash-first-URI">
          <xsl:with-param name="URIs" select="$me"/>
          <xsl:with-param name="me" select="local-name(.)"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:value-of select="normalize-space($hashed-URIs)"/>
    </xsl:attribute>
    <xsl:if test="contains( $me_sans_path, ' ')">
      <xsl:call-template name="hash-first-URI">
        <xsl:with-param name="out" select="'attr'"/>
        <xsl:with-param name="URIs" select="$me"/>
        <xsl:with-param name="me" select="local-name(.)"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>
  
  <!-- *************************** -->
  <!-- data processing subroutines -->
  <!-- *************************** -->
  
  <xsl:template name="process-first-URI">
    <xsl:param name="URIs"/>
    <xsl:choose>
      <xsl:when test="contains($URIs,' ')">
        <xsl:call-template name="process-first-URI">
          <xsl:with-param name="URIs" select="substring-before($URIs,' ')"/>
        </xsl:call-template>
        <xsl:call-template name="process-first-URI">
          <xsl:with-param name="URIs" select="substring-after($URIs,' ')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:choose>
          <xsl:when test="
            starts-with($URIs,'http://')
            or starts-with($URIs,'https://')
            or starts-with($URIs,'mailto:/')
            or starts-with($URIs,'ftp://')
            ">
            <!-- what other protocols should we be ignoring? -->
            <xsl:value-of select="$URIs"/>
          </xsl:when>
          <xsl:when test=" starts-with($URIs,'file:/')">
            <!-- for file:, just treat it like an absolute filepath -->
            <!-- by stripping off the initial "file:" bit -->
            <xsl:call-template name="remove-path-component">
              <xsl:with-param name="me" select="substring-after($URIs,':')"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <!-- recursively remove the first path component, so we end -->
            <!-- up with whatever is after ultimate slash -->
            <xsl:call-template name="remove-path-component">
              <xsl:with-param name="me" select="$URIs"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:text>&#x20;</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template name="hash-first-URI">
    <xsl:param name="me"/>
    <xsl:param name="URIs"/>
    <xsl:param name="depth" select="0"/>
    <xsl:param name="out" select="'string'"/>
    <xsl:choose>
      <xsl:when test="contains($URIs,' ')">
        <xsl:call-template name="hash-first-URI">
          <xsl:with-param name="depth" select="$depth"/>
          <xsl:with-param name="out" select="$out"/>
          <xsl:with-param name="URIs" select="substring-before($URIs,' ')"/>
          <xsl:with-param name="me" select="$me"/>
        </xsl:call-template>
        <xsl:call-template name="hash-first-URI">
          <xsl:with-param name="depth" select="$depth+1"/>
          <xsl:with-param name="out" select="$out"/>
          <xsl:with-param name="URIs" select="substring-after($URIs,' ')"/>
          <xsl:with-param name="me" select="$me"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <!-- convert any non-NCName characters into allowed ones -->
        <xsl:variable name="one"   select="translate($URIs, $URIc1,'......')"/>
        <xsl:variable name="two"   select="translate( $one, $URIc2, '______')"/>
        <xsl:variable name="three" select="translate( $two, $URIc3, '------')"/>
        <xsl:variable name="four">
          <!-- if starts with an illegal name start char, prepend one -->
          <xsl:choose>
            <xsl:when test="contains( '._-', substring( $three, 1, 1) )">
              <xsl:value-of select="concat( 'Ћ', $three )"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="$three"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:choose>
          <xsl:when test="$out = 'string'">
            <xsl:value-of select="concat( $four, ' ')"/>    
          </xsl:when>
          <xsl:when test="$out = 'attr'">
            <xsl:attribute name="data-tapas-hashed-{$me}-{$depth+1}">
              <xsl:value-of select="$four"/>
            </xsl:attribute>
            <xsl:attribute name="data-tapas-{$me}-{$depth+1}">
              <xsl:value-of select="$URIs"/>
            </xsl:attribute>
          </xsl:when>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template name="remove-path-component">
    <xsl:param name="me"/>
    <xsl:variable name="url">
      <xsl:choose>
        <xsl:when test="contains($me,'#')"><xsl:value-of select="substring-before($me,'#')"/></xsl:when>
        <xsl:otherwise><xsl:value-of select="$me"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="fragi">
      <xsl:choose>
        <xsl:when test="contains($me,'#')"><xsl:value-of select="substring-after($me,'#')"/></xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="url-sans-path">
      <xsl:choose>
        <xsl:when test="contains( $url,'/')">
          <xsl:call-template name="remove-path-component">
            <xsl:with-param name="me" select="substring-after( $url,'/')"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise><xsl:value-of select="$url"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$fragi = ''">
        <xsl:value-of select="$url-sans-path"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$url-sans-path"/>
        <xsl:text>#</xsl:text>
        <xsl:value-of select="$fragi"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
