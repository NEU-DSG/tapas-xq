<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:eg="http://www.tei-c.org/ns/Examples"
                xmlns:tei="http://www.tei-c.org/ns/1.0"
                xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
                xmlns="http://www.w3.org/1999/xhtml"
                xmlns:html="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="xsl tei xd eg #default">
  <xd:doc scope="stylesheet">
    <xd:desc>
      <xd:p><xd:b>Created on:</xd:b> 2013-04-16 by Syd Bauman, based
        entirely on 'genericTEI2genericXHTML5.xslt', itself based
      very heavily on 'teibp.xsl' (part of TEI Bolerplate) by John A.
      Walsh</xd:p>
      <xd:p>TAPAS generic: Copies TEI document, with a few
      modifications into an HTML 5 shell; intended for use 
      when no javascript is available.</xd:p>
    </xd:desc>
  </xd:doc>

  <xsl:include href="xml-to-string.xsl"/>
  <xsl:output encoding="UTF-8" method="xml" omit-xml-declaration="yes"/>

  <xsl:param name="teibpHome" select="'http://dcl.slis.indiana.edu/teibp/'"/>
  <xsl:param name="tapasHome" select="'http://tapasproject.org/'"/>
  <xsl:param name="tapasTitle" select="'TAPAS: '"/>
  <xsl:param name="filePrefix" select="'..'"/>
  <xsl:param name="tapasGenericCSS" select="concat($filePrefix,'/css/tapasG.css')"/>
  <xsl:param name="customCSS" select="concat($filePrefix,'/css/custom.css')"/>

  <xsl:key name="IDs" match="//*" use="@xml:id"/>
  <xsl:variable name="htmlFooter">
    <div id="footer">
      <p>This is a pre-alpha version of the <a href="{$tapasHome}">TAPAS</a> generic
        view, based on <a href="http://teiboilerplate.org/">TEI Boilerplate</a> by John Walsh.</p>
    </div>
  </xsl:variable>
  
  <xd:doc>
    <xd:desc>
      <xd:p>Match document root and create an html5 wrapper for the
      TEI document, which is copied, with some modification, into the
      HTML document.</xd:p>
    </xd:desc>
  </xd:doc>
  <xsl:template match="/" name="htmlShell">
    <html>
      <xsl:call-template name="htmlHead"/>
      <body>
        <div id="tei_wrapper">
          <xsl:apply-templates/>
        </div>
        <xsl:copy-of select="$htmlFooter"/>
      </body>
    </html>
  </xsl:template>

  <xd:doc>
    <xd:desc>
      <xd:p>Copy all attribute nodes from source XML tree to
      output document.</xd:p>
    </xd:desc>
  </xd:doc>
  <xsl:template match="@*">
    <xsl:copy/>
  </xsl:template>

  <xd:doc>
    <xd:desc>
      <xd:p>Template for elements.
        Note that the priority for the "tei:*" template is -0.25, whereas the
        priority for the plain "*" template is -0.5. Thus TEI elements will get
        the following treatment:
        <xd:ul>
          <xd:li>ensure there is an <xd:i>id</xd:i> to every element (copy existing <xd:i>xml:id</xd:i> or add new)</xd:li>
          <xd:li>process rendition attributes</xd:li>
          <xd:li>copy over other (non-rendition) attributes</xd:li>
          <xd:li>chase the <xd:i>ref</xd:i> attributes, and copy over whatever they point to</xd:li>
          <xd:li>copy all content</xd:li>
        </xd:ul>
        and elements in other namespaces will get summarily dropped.
      </xd:p>
    </xd:desc>
  </xd:doc>
  <xsl:template match="tei:*">
    <xsl:copy>
      <xsl:call-template name="addID"/>
      <xsl:call-template name="addRend"/>
      <xsl:apply-templates select="@*[not( starts-with(local-name(.),'rend') ) and not( local-name(.)='style' )]"/>
      <xsl:call-template name="contextual"/>
      <xsl:apply-templates select="node()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="*"/>

  <xd:doc>
    <xd:desc>
      <xd:p>Template to omit processing instructions and comments from output.</xd:p>
    </xd:desc>
  </xd:doc>
  <xsl:template match="processing-instruction()|comment()"/>

  <xsl:template name="rendition">
    <xsl:if test="@rendition">
      <xsl:attribute name="rendition">
        <xsl:value-of select="@rendition"/>
      </xsl:attribute>
    </xsl:if>
  </xsl:template>

  <xsl:template match="@xml:id">
    <!-- copy @xml:id to @id, which browsers use for internal links. -->
    <xsl:attribute name="id">
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>

  <xd:doc>
    <xd:desc>
      <xd:p>Transforms TEI ref element to html a (link) element.</xd:p>
    </xd:desc>
  </xd:doc>
  <xsl:template match="tei:ref[@target]" priority="99">
    <a href="{@target}">
      <xsl:call-template name="rendition"/>
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <xd:doc>
    <xd:desc>
      <xd:p>Transforms TEI ptr element to html a (link) element.</xd:p>
    </xd:desc>
  </xd:doc>
  <xsl:template match="tei:ptr[@target]" priority="99">
    <a href="{@target}">
      <xsl:call-template name="rendition"/>
      <xsl:value-of select="normalize-space(@target)"/>
    </a>
  </xsl:template>


  <!-- need something else for images with captions -->
  <xd:doc>
    <xd:desc>
      <xd:p>Transforms TEI figure element to html img element.</xd:p>
    </xd:desc>
  </xd:doc>
  <xsl:template match="tei:figure[tei:graphic[@url]]" priority="99">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:call-template name="addID"/>
      <img alt="{normalize-space(tei:figDesc)}" src="{tei:graphic/@url}"/>
      <xsl:apply-templates select="*[local-name() != 'graphic' and local-name() != 'figDesc']"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template name="addID">
    <xsl:if test="not(@xml:id) and not(ancestor::eg:egXML)">
      <xsl:attribute name="id">
        <xsl:call-template name="generate-unique-id">
          <xsl:with-param name="root" select="generate-id()"/>
        </xsl:call-template>
      </xsl:attribute>
    </xsl:if>
  </xsl:template>

  <xsl:template name="addRend">
    <xsl:apply-templates select="@rendition"/>
    <xsl:if test="@rend | @html:style | @style">
      <xsl:attribute name="style">
        <xsl:variable name="rend">
          <xsl:apply-templates select="@rend" mode="addRend"/>
        </xsl:variable>
        <xsl:value-of select="$rend"/>
        <xsl:if test="$rend and not( substring($rend,string-length($rend),1) = ';')">
          <xsl:text>; </xsl:text>
        </xsl:if>
        <xsl:variable name="Tstyle" select="normalize-space(@style)"/>
        <xsl:apply-templates select="@style" mode="addRend"/>
        <xsl:if test="@style and not( substring($Tstyle,string-length($Tstyle),1) = ';')">
          <xsl:text>; </xsl:text>
        </xsl:if>
        <xsl:variable name="Hstyle" select="normalize-space(@html:style)"/>
        <xsl:apply-templates select="@html:style" mode="addRend"/>
        <xsl:if test="@html:style and not( substring($Hstyle,string-length($Hstyle),1) = ';')">
          <xsl:text>; </xsl:text>
        </xsl:if>
      </xsl:attribute>
    </xsl:if>
  </xsl:template>
  <xsl:template match="@style | @html:style" mode="addRend">
    <xsl:value-of select="normalize-space(.)"/>
  </xsl:template>
  <xsl:template match="@rend" mode="addRend">
    <xsl:variable name="rend" select="normalize-space(.)"/>
    <xsl:variable name="css">
      <xsl:choose>
        <xsl:when test="contains( $rend, ':' )"><xsl:value-of select="."/></xsl:when>   <!-- 30937 -->
        <xsl:when test="$rend = 'italic'"           >font-style: italic;</xsl:when>     <!-- 24857 -->
        <xsl:when test="$rend = 'visible'"          ></xsl:when>                        <!--  1673 -->
        <xsl:when test="$rend = 'superscript'"      >vertical-align: super;</xsl:when>  <!--  1175 -->
        <xsl:when test="$rend = 'bold'"             >font-weight: bold;</xsl:when>      <!--   920 -->
        <xsl:when test="$rend = 'ti-1'"             ></xsl:when>                        <!--   741 -->
        <xsl:when test="$rend = 'center'"           >text-align: center;</xsl:when>     <!--   657 -->
        <xsl:when test="$rend = 'rectangle'"        ></xsl:when>                        <!--   639 -->
        <xsl:when test="$rend = 'right'"            >text-align: right;</xsl:when>      <!--   617 -->
        <xsl:when test="$rend = 'i'"                >font-style: italic;</xsl:when>     <!--   449 -->
        <xsl:when test="$rend = 'ul'"               >text-decoration: underline;</xsl:when> <!--   381 -->
        <xsl:when test="$rend = 'align(center)'"    >text-align: center;</xsl:when>     <!--   301 -->
        <xsl:when test="$rend = ''"                 ></xsl:when>                        <!--   207 -->
        <xsl:when test="$rend = 'align(CENTER)'"    >text-align: center;</xsl:when>     <!--   202 -->
        <xsl:when test="$rend = 'headerlike'"       ></xsl:when>                        <!--   189 -->
        <xsl:when test="$rend = 'super'"            >vertical-align: super;</xsl:when>  <!--   161 -->
        <xsl:when test="$rend = 'align(RIGHT)'"     >text-align: right;</xsl:when>      <!--   111 -->
        <xsl:when test="$rend = 'valign(bottom)'"   >vertical-align: bottom;</xsl:when> <!--   104 -->
        <xsl:when test="$rend = 'align(right)'"     >text-align: right;</xsl:when>      <!--   101 -->
        <xsl:when test="$rend = 'blockquote'"       ></xsl:when>                        <!--    85 -->
        <xsl:when test="$rend = 'ti-3'"             ></xsl:when>                        <!--    84 -->
        <xsl:when test="$rend = 'run-in'"           >display: run-in;</xsl:when>        <!--    80 -->
        <xsl:when test="$rend = 'valign(TOP)'"      >vertical-align: top;</xsl:when>    <!--    78 -->
        <xsl:when test="$rend = 'distinct'"         ></xsl:when>                        <!--    78 -->
        <xsl:when test="$rend = 'valign(top)'"      >vertical-align: top;</xsl:when>    <!--    77 -->
        <xsl:when test="$rend = 'ti-2'"             ></xsl:when>                        <!--    73 -->
        <xsl:when test="$rend = '+'"                ></xsl:when>                        <!--    63 -->
        <xsl:when test="$rend = 'valign(BOTTOM)'"   >vertical-align: bottom;</xsl:when> <!--    55 -->
        <xsl:when test="$rend = 'large b'"          >font-size: larger;font-weight: bold;</xsl:when> <!--    55 -->
        <xsl:when test="$rend = 'frame'"            ></xsl:when>                        <!--    44 -->
        <xsl:when test="$rend = 'ti-4'"             ></xsl:when>                        <!--    29 -->
        <xsl:when test="$rend = 'sup'"              >vertical-align: super;</xsl:when>  <!--    27 -->
        <xsl:when test="$rend = 'b'"                >font-weight: bold;</xsl:when>      <!--    27 -->
        <xsl:when test="$rend = 'vertical'"         ></xsl:when>                        <!--    21 -->
        <xsl:when test="$rend = 'LHLineStart'"      ></xsl:when>                        <!--    15 -->
        <xsl:when test="$rend = 'indent'"           ></xsl:when>                        <!--    15 -->
        <xsl:when test="$rend = 'sc'"               >font-variant: small-caps;</xsl:when> <!--    10 -->
        <xsl:when test="$rend = 'overstrike'"       >text-decoration: overline;</xsl:when> <!--    10 -->
        <xsl:when test="$rend = 'spaced'"           >font-stretch: wider;</xsl:when>    <!--     8 -->
        <xsl:when test="$rend = 'left'"             >text-align: left;</xsl:when>       <!--     8 -->
        <xsl:when test="$rend = 'AboveCenter'"      ></xsl:when>                        <!--     7 -->
        <xsl:when test="$rend = 'subscript'"        >vertical-align: sub;</xsl:when>    <!--     6 -->
        <xsl:when test="$rend = 'sc center'"        >font-variant: small-caps;text-align: center;</xsl:when> <!--     6 -->
        <xsl:when test="$rend = 'underline'"        >text-decoration: underline;</xsl:when> <!--     5 -->
        <xsl:when test="$rend = 'printed'"          ></xsl:when>                        <!--     5 -->
        <xsl:when test="$rend = 'hidden'"           >display: none;</xsl:when>          <!--     5 -->
        <xsl:when test="$rend = 'continued'"        ></xsl:when>                        <!--     5 -->
        <xsl:when test="$rend = 'c'"                ></xsl:when>                        <!--     5 -->
        <xsl:when test="$rend = 'inline'"           ></xsl:when>                        <!--     4 -->
        <xsl:when test="$rend = 'typescript'"       ></xsl:when>                        <!--     3 -->
        <xsl:when test="$rend = 'sc right'"         >font-variant: small-caps;text-align: right;</xsl:when> <!--     3 -->
        <xsl:when test="$rend = 'LHMargin'"         ></xsl:when>                        <!--     3 -->
        <xsl:when test="$rend = 'foot'"             ></xsl:when>                        <!--     3 -->
        <xsl:when test="$rend = 'strikethrough'"    >text-decoration: line-through;</xsl:when> <!--     2 -->
        <xsl:when test="$rend = 'small caps'"       >font-variant: small-caps;</xsl:when> <!--     2 -->
        <xsl:when test="$rend = 'gothic'"           ></xsl:when>                        <!--     2 -->
        <xsl:when test="$rend = 'font-size; 225%'"  ></xsl:when>                        <!--     2 -->
        <xsl:when test="$rend = 'font-size; 200%'"  ></xsl:when>                        <!--     2 -->
        <xsl:when test="$rend = 'chapter'"          ></xsl:when>                        <!--     2 -->
        <xsl:when test="$rend = 'center i'"         >text-align: center;font-style: italic;</xsl:when> <!--     2 -->
        <xsl:when test="$rend = 'uc'"               >text-transform: uppercase;</xsl:when> <!--     1 -->
        <xsl:when test="$rend = 'ti-5'"             ></xsl:when>                        <!--     1 -->
        <xsl:when test="$rend = 'ti=3'"             ></xsl:when>                        <!--     1 -->
        <xsl:when test="$rend = 'ti=2'"             ></xsl:when>                        <!--     1 -->
        <xsl:when test="$rend = 'text-align-left;'" ></xsl:when>                        <!--     1 -->
        <xsl:when test="$rend = 'noborder center'"  ></xsl:when>                        <!--     1 -->
        <xsl:when test="$rend = 'margin-bottom;'"   ></xsl:when>                        <!--     1 -->
        <xsl:when test="$rend = 'italic bold'"      ></xsl:when>                        <!--     1 -->
        <xsl:when test="$rend = 'i distinct'"       ></xsl:when>                        <!--     1 -->
        <xsl:when test="$rend = 'font-size;225%'"   ></xsl:when>                        <!--     1 -->
        <xsl:when test="$rend = 'font-size;150%'"   ></xsl:when>                        <!--     1 -->
        <xsl:when test="$rend = 'font-size; 150%'"  ></xsl:when>                        <!--     1 -->
        <xsl:when test="$rend = 'center ti-8'"      ></xsl:when>                        <!--     1 -->
        <xsl:when test="$rend = 'center b'"         ></xsl:when>                        <!--     1 -->
        <xsl:when test="$rend = 'Center'"           ></xsl:when>                        <!--     1 -->
        <xsl:when test="$rend = 'above'"            ></xsl:when>                        <!--     1 -->
        <xsl:when test="$rend = '20'"               ></xsl:when>                        <!--     1 -->
        <xsl:otherwise>
          <xsl:value-of select="."/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:value-of select="$css"/>
  </xsl:template>

  <xd:doc>
    <xd:desc>
      <xd:p>The generate-id() function does not guarantee the generated id will not conflict
      with existing ids in the document. This template checks for conflicts and appends a
      number (hexedecimal 'f') to the id. The template is recursive and continues until no
      conflict is found</xd:p>
    </xd:desc>
    <xd:param name="root">The root, or base, id used to check for conflicts</xd:param>
    <xd:param name="suffix">The suffix added to the root id if a conflict is
    detected.</xd:param>
  </xd:doc>
  <xsl:template name="generate-unique-id">
    <xsl:param name="root"/>
    <xsl:param name="suffix"/>
    <xsl:variable name="id" select="concat($root,$suffix)"/>
    <xsl:choose>
      <xsl:when test="key('IDs',$id)">
        <xsl:call-template name="generate-unique-id">
          <xsl:with-param name="root" select="$root"/>
          <xsl:with-param name="suffix" select="concat($suffix,'f')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$id"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xd:doc>
    <xd:desc>
      <xd:p>Template for adding /html/head content.</xd:p>
    </xd:desc>
  </xd:doc>
  <xsl:template name="htmlHead">
    <head>
      <meta charset="UTF-8"/>
      <link id="maincss" rel="stylesheet" type="text/css" href="{$tapasGenericCSS}"/>
      <link id="custcss" rel="stylesheet" type="text/css" href="{$customCSS}"/>
      <xsl:call-template name="rendition2style"/>
      <xsl:call-template name="generate-title"/>
    </head>
  </xsl:template>

  <xsl:template name="rendition2style">
    <style type="text/css">
      <xsl:apply-templates select="//tei:rendition" mode="rendition2style"/>
    </style>
  </xsl:template>

  <xsl:template match="tei:rendition[@xml:id and @scheme = 'css']" mode="rendition2style">
    <xsl:value-of select="concat('[rendition~=&quot;#',@xml:id,'&quot;]')"/>
    <xsl:if test="@scope">
      <xsl:value-of select="concat(':',@scope)"/>
    </xsl:if>
    <xsl:value-of select="concat('{ ',normalize-space(.),'}&#x000A;')"/>
  </xsl:template>

  <xsl:template match="tei:rendition[not(@xml:id) and @scheme = 'css' and @corresp]" mode="rendition2style">
    <xsl:value-of select="concat('[rendition~=&quot;#',substring-after(@corresp,'#'),'&quot;]')"/>
    <xsl:if test="@scope">
      <xsl:value-of select="concat(':',@scope)"/>
    </xsl:if>
    <xsl:value-of select="concat('{ ',normalize-space(.),'}&#x000A;')"/>
  </xsl:template>
  
  <xsl:template match="eg:egXML">
    <xsl:element name="{local-name()}">
      <xsl:apply-templates select="@*"/>
      <xsl:call-template name="addID"/>
      <xsl:call-template name="xml-to-string">
        <xsl:with-param name="node-set">
          <xsl:copy-of select="node()"/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:element>
  </xsl:template>

  <xsl:template match="eg:egXML//comment()">
    <xsl:comment><xsl:value-of select="."/></xsl:comment>
  </xsl:template>

  <xsl:template name="generate-title">
    <title>
      <xsl:value-of select="$tapasTitle"/>
      <xsl:choose>
        <xsl:when test="count( /tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title ) = 1">
          <xsl:value-of select="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title"/>
        </xsl:when>
        <xsl:when test="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type='short']">
          <xsl:for-each select="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type='short']">
            <xsl:value-of select="concat(.,' ')"/>
          </xsl:for-each>
        </xsl:when>
        <xsl:when test="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type='filing']">
          <xsl:for-each select="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type='filing']">
            <xsl:value-of select="concat(.,' ')"/>
          </xsl:for-each>
        </xsl:when>
        <xsl:when test="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type='uniform']">
          <xsl:for-each select="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type='uniform']">
            <xsl:value-of select="concat(.,' ')"/>
          </xsl:for-each>
        </xsl:when>
        <xsl:when test="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type='main']">
          <xsl:for-each select="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type='main']">
            <xsl:value-of select="concat(.,' ')"/>
          </xsl:for-each>
        </xsl:when>
        <xsl:when test="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type='marc245a']">
          <xsl:for-each select="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type='marc245a']">
            <xsl:value-of select="concat(.,' ')"/>
          </xsl:for-each>
        </xsl:when>
        <xsl:when test="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@level='a']">
          <xsl:for-each select="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[@type='a']">
            <xsl:value-of select="concat(.,' ')"/>
          </xsl:for-each>
        </xsl:when>
        <xsl:otherwise>
          <xsl:for-each select="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title">
            <xsl:value-of select="concat(.,' ')"/>
          </xsl:for-each>
        </xsl:otherwise>
      </xsl:choose>
    </title>
  </xsl:template>
  
  <xsl:template name="contextual">
    <xsl:if test="@ref and not(self::tei:g)">
      <xsl:attribute name="href">
        <xsl:value-of select="@ref"/>
      </xsl:attribute>
      <xsl:variable name="fragmentIdentifier" select="substring-after( @ref, '#')"/>
      <xsl:attribute name="title">
        <xsl:apply-templates select="document( substring-before( @ref, '#'), /tei:* )//*[@xml:id = $fragmentIdentifier]" mode="string"/>
      </xsl:attribute>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="tei:*" mode="string">
    <xsl:apply-templates select="text()|tei:*" mode="string"/>
  </xsl:template>
  
  <xsl:template match="text()" mode="string">
    <xsl:value-of select="concat('&#x0A;',normalize-space(.),' ')"/>
  </xsl:template>
  
</xsl:stylesheet>
