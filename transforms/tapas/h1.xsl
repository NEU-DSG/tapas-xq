<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:eg="http://www.tei-c.org/ns/Examples"
                xmlns:tei="http://www.tei-c.org/ns/1.0"
                xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
                xmlns="http://www.w3.org/1999/xhtml"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                exclude-result-prefixes="xsi xsl tei xd eg #default">
  <xd:doc scope="stylesheet">
    <xd:desc>
      <xd:p><xd:b>Created on:</xd:b> 2013-03-28 by Syd Bauman, based
      very heavily on 'teibp.xsl' (part of TEI Bolerplate) by John A.
      Walsh</xd:p>
      <xd:p>TAPAS generic: Copies TEI document, with a very few
      modifications into an HTML 5 shell, which provides access to
      javascript and other features from the html/browser
      environment.</xd:p>
      <xd:p><xd:b>change log:</xd:b></xd:p>
      <xd:p><xd:i>2014-03-16</xd:i> by Syd: <xd:i>finally</xd:i> put in Patrick's
      2014-10-02 request for an <tt>html:span</tt> before each <tt>tei:note</tt>.</xd:p>
      <xd:p><xd:i>2013-10-21/22</xd:i> by Syd: incorporate changes John and
      Grant have made to Boilerplate. In particular, page facsimile system,
      and their version of <xd:pre>&lt;tagUsage></xd:pre> processing.</xd:p>
      <xd:p><xd:i>2013-11-06 ~11:45</xd:i> change to using client-side LESS
      instead of CSS (processed by server-side LESS) directly</xd:p>
      <xd:p><xd:i>2013-11-06 ~17:56</xd:i>
        <xd:ul>
          <xd:li>re-worked how PB is processed: removed 'pb-handler' template, as it wasn't saving much; use @n if availble, if not count of PB so far (icky); handle prose part (was $pbNote) in CSS instead, so remove that and made its SPAN an A (since it no longer has content)</xd:li>
          <xd:li>added lessSide paramater, so we can switch back &amp; forth how we use LESS easily</xd:li>
        </xd:ul>
      </xd:p>
    </xd:desc>
  </xd:doc>

  <!-- xsl:include href="xml-to-string.xsl"/ -->

  <xsl:output encoding="UTF-8" method="xml" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="teibpHome"  select="'http://dcl.slis.indiana.edu/teibp/'"/>
  <xsl:param name="tapasHome"  select="'http://tapasproject.org/'"/>
  <xsl:param name="tapasTitle" select="'TAPAS: '"/>
  <xsl:param name="less"       select="'styles.less'"/>
  <xsl:param name="lessJS"     select="'less.js'"/>
  <!-- set filePrefix parameter to ".." to use locally; path below is for within-TAPAS use -->
  <xsl:param name="filePrefix" select="'/sites/all/modules/tapas_transform/transforms/tapas'"/>
  <xsl:param name="view.diplo" select="concat($filePrefix,'/css/tapasGdiplo.css')"/>
  <xsl:param name="view.norma" select="concat($filePrefix,'/css/tapasGnormal.css')"/>
  <!-- JQuery is not being used at the moment, but we may be putting it back -->
  <xsl:param name="jqueryJS"   select="concat($filePrefix,'/js/jquery/jquery.min.js')"/>
  <xsl:param name="jqueryBlockUIJS" select="concat($filePrefix,'/js/jquery/plugins/jquery.blockUI.js')"/>
  <xsl:param name="teibpJS"    select="concat($filePrefix,'/js/teibp.js')"/>
  <xsl:variable name="htmlFooter">
    <div id="footer"> This is the <a href="{$tapasHome}">TAPAS</a> generic view.</div>
  </xsl:variable>
  <xsl:param name="displayPageBreaks" select="true()"/>
  <xsl:param name="lessSide" select="'server'"/><!-- 'server' or 'client' -->
  <xsl:variable name="numNotes" select="count( /tei:TEI/tei:text//tei:note )"/>
  <!-- WARNING: above line ignores possibility of a <teiCorpus> -->
  <xsl:variable name="numNoteFmt">
    <xsl:variable name="nNF1" select="translate( $numNotes, '0123456789','0000000000')"/>
    <xsl:variable name="nNF2" select="substring( $nNF1, 1, string-length( $nNF1 ) - 1 )"/>
    <xsl:value-of select="concat( $nNF2, '1' )"/>
  </xsl:variable>

  <xsl:key name="IDs" match="//*" use="@xml:id"/>

  <!-- special characters -->
  <xsl:variable name="quot"><text>"</text></xsl:variable>
  <xsl:variable name="apos"><text>'</text></xsl:variable>
  <xsl:variable name="lcub" select="'{'"/>
  <xsl:variable name="rcub" select="'}'"/>

  <!-- interface text -->
  <xsl:param name="altTextPbFacs" select="'view page image(s)'"/>

  <!-- input document -->
  <xsl:variable name="input" select="/"/>

  <xd:doc>
    <xd:desc>
      <xd:p>Match document root and create and html5 wrapper for the
      TEI document, which is copied, with some modification, into the
      HTML document.</xd:p>
    </xd:desc>
  </xd:doc>
  <xsl:template match="/" name="htmlShell">
    <html>
      <xsl:call-template name="htmlHead"/>
      <body>
        <xsl:call-template name="toolbox"/>
        <xsl:call-template name="dialog"/>
        <xsl:call-template name="wrapper"/>
        <xsl:call-template name="contextual"/>
        <xsl:copy-of select="$htmlFooter"/>
      </body>
    </html>
  </xsl:template>

  <xsl:template name="toolbox">
    <div id="tapasToolbox">
      <div id="tapasToolbox-pb">
        <label for="pbToggle">Hide page breaks</label>
        <input type="checkbox" id="pbToggle" />
      </div>
      <div id="tapasToolbox-views">
        <label for="viewBox">Views</label>
        <select id="viewBox">
          <!-- this <select> used to have on[cC]hange="switchThemes(this);", but -->
          <!-- that was incorporated into the javascript 2014-04-20 by PMJ. -->
          <option value="{$view.diplo}" selected="selected">diplomatic</option>
          <option value="{$view.norma}">normalized</option>
        </select>
      </div>
    </div>
  </xsl:template>

  <xsl:template name="dialog">
    <div id="tapas-ref-dialog"/>
  </xsl:template>

  <xsl:template name="wrapper">
    <div id="tei_wrapper">
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template name="contextual">
    <div id="tei_contextual">
      <xsl:for-each select="
        //@data-tapas-hashed-ref
        [ not( ../@data-tapas-ref-1 ) ]
        [ parent::tei:name or parent::tei:orgName or parent::tei:persName or parent::tei:rs ]
        [ not(. =  preceding::*[self::tei:name or self::tei:orgName or self::tei:persName or self::tei:placeName or self::tei:rs]/@data-tapas-hashed-ref) ]
        [ not(. =  preceding::*[self::tei:name or self::tei:orgName or self::tei:persName or self::tei:placeName or self::tei:rs]/@data-tapas-hashed-ref-1) ]
        |
        //@data-tapas-hashed-ref-1
        [ parent::tei:name or parent::tei:orgName or parent::tei:persName or parent::tei:rs ]
        [ not(. =  preceding::*[self::tei:name or self::tei:orgName or self::tei:persName or self::tei:placeName or self::tei:rs]/@data-tapas-hashed-ref) ]
        [ not(. =  preceding::*[self::tei:name or self::tei:orgName or self::tei:persName or self::tei:placeName or self::tei:rs]/@data-tapas-hashed-ref-1) ]
        ">
        <xsl:sort select="concat(local-name(..),'=',.)"/>
        <xsl:variable name="hashedRef">
          <xsl:choose>
            <xsl:when test="local-name(.) = 'data-tapas-hashed-ref'">
              <xsl:value-of select="../@data-tapas-hashed-ref"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="../@data-tapas-hashed-ref-1"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:call-template name="generateContextItem">
          <xsl:with-param name="ref" select="../@ref"/>
          <xsl:with-param name="hashedRef" select="$hashedRef"/>
        </xsl:call-template>
      </xsl:for-each>
    </div>
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
      <xd:ul>
        <xd:li>ensure there is an <xd:i>id</xd:i> to every element (copy existing <xd:i>xml:id</xd:i> or add new)</xd:li>
        <xd:li>process rendition attributes</xd:li>
        <xd:li>copy over other (non-rendition) attributes</xd:li>
        <xd:li>chase the <xd:i>ref</xd:i> attributes, and copy over whatever they point to</xd:li>
        <xd:li>copy all content</xd:li>
      </xd:ul>
      </xd:p>
    </xd:desc>
  </xd:doc>
  <xsl:template match="*">
    <xsl:copy>
      <xsl:call-template name="addID"/>
      <xsl:call-template name="addRend"/>
      <xsl:apply-templates select="@*[not( starts-with(local-name(.),'rend') ) and not( local-name(.)='style' )]"/>
      <xsl:apply-templates select="node()"/>
    </xsl:copy>
  </xsl:template>

  <xd:doc>
    <xd:desc>
      <xd:p>A hack because JavaScript was doing weird things with
      &lt;title>, probably due to confusion with HTML title. There is
      no TEI namespace in the TEI Boilerplate output because
      JavaScript, or at least JQuery, cannot manipulate the TEI
      elements/attributes if they are in the TEI namespace, so the TEI
      namespace is stripped from the output. As far as I know,
      &lt;title> elsewhere does not cause any problems, but we may
      need to extend this to other occurrences of &lt;title> outside
      the Header.</xd:p>
      <xd:p>WARNING — for now we are putting the TEI namespace into
        output, as we (TAPAS) are not using JQuery.</xd:p>
    </xd:desc>
  </xd:doc>
  <xsl:template match="tei:teiHeader//tei:title">
    <tei-title>
      <xsl:call-template name="addID"/>
      <xsl:apply-templates select="@*|node()"/>
    </tei-title>
  </xsl:template>

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
      <xsl:apply-templates select="@*[not( local-name(.) = 'target') ]"/>
      <xsl:call-template name="rendition"/>
      <xsl:apply-templates select="node()"/>
    </a>
  </xsl:template>

  <xd:doc>
    <xd:desc>
      <xd:p>Transforms TEI ptr element to html a (link) element.</xd:p>
    </xd:desc>
  </xd:doc>
  <xsl:template match="tei:ptr[@target]" priority="99">
    <a href="{@target}">
      <xsl:apply-templates select="@*[not( local-name(.) = 'target') ]"/>
      <xsl:call-template name="rendition"/>
      <xsl:value-of select="normalize-space(@target)"/>
    </a>
  </xsl:template>
  
  <xd:doc>
    <xd:desc>Insert an HTML note-anchor before each <tt>&lt;note></tt>, except those
    that already have something pointing at them</xd:desc>
  </xd:doc>
  <xsl:template match="tei:text//tei:note" priority="99">
    <xsl:variable name="noteNum">
      <xsl:number value="count( preceding::tei:note[ancestor::tei:text] )+1" format="{$numNoteFmt}"/>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="@xml:id  and  ( //@target ) = concat('#',@xml:id )"/>
      <xsl:otherwise>
        <span class="note-marker">
          <xsl:value-of select="$noteNum"/>
        </span>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:copy>
      <xsl:attribute name="data-tapas-note-num">
        <xsl:value-of select="$noteNum"/>
      </xsl:attribute>
      <xsl:call-template name="addID"/>
      <xsl:call-template name="addRend"/>
      <xsl:apply-templates select="@*[not( starts-with(local-name(.),'rend') ) and not( local-name(.)='style' )]"/>
      <xsl:apply-templates select="node()"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- need something else for images with captions; specifically
       may want to catch figure/p, figure/floatingText, and figure/head
       with separate templates. -->
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
      <xsl:apply-templates select="*[ not( self::tei:graphic | self::tei:figDesc ) ]"/>
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
    <xsl:if test="@rend | @html:style | @style | @tei:style">
      <xsl:attribute name="style">
        <xsl:variable name="rend">
          <xsl:apply-templates select="@rend" mode="rendition2style"/>
        </xsl:variable>
        <xsl:value-of select="$rend"/>
        <xsl:if test="$rend and not( substring($rend,string-length($rend),1) = ';')">
          <xsl:text>; </xsl:text>
        </xsl:if>
        <xsl:apply-templates select="@tei:style"/>
        <xsl:apply-templates select="@style"/>
        <xsl:apply-templates select="@html:style"/>
      </xsl:attribute>
    </xsl:if>
  </xsl:template>
  <xsl:template match="@tei:style | @style | @html:style">
    <!-- note: matching "attribute::*[local-name(.)='style']" chokes in PHP's XSLT processor -->
    <xsl:variable name="result" select="normalize-space(.)"/>
    <xsl:value-of select="$result"/>
    <xsl:if test="not( substring($result,string-length($result),1) = ';')">
      <xsl:text>; </xsl:text>
    </xsl:if>
  </xsl:template>
  <xsl:template match="@rend" mode="rendition2style">
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
          <xsl:message>WARNING: I don't know what to do with rend="<xsl:value-of select="."/>"</xsl:message>
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

  <xsl:template name="htmlHead">
    <head>
      <meta charset="UTF-8"/>
      <xsl:choose>
        <xsl:when test="$lessSide='client'">
          <link rel="stylesheet/less" type="text/css" href="{$less}"/>
          <script src="less.js" type="text/javascript"/>
        </xsl:when>
        <xsl:otherwise>
          <link id="maincss" rel="stylesheet" type="text/css" href="{$view.diplo}"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:call-template name="javascript"/>
      <xsl:call-template name="css"/>
      <xsl:call-template name="tagUsage2style"/>
      <xsl:call-template name="rendition2style"/>
      <xsl:call-template name="generate-title"/>
    </head>
  </xsl:template>

  <xsl:template name="javascript">
    <script type="text/javascript" src="{$filePrefix}/js/jquery/jquery.min.js"/>
    <script type="text/javascript" src="{$filePrefix}/js/jquery-ui/ui/minified/jquery-ui.min.js"/>
    <script type="text/javascript" src="{$filePrefix}/js/contextualItems.js"/>
    <link rel="stylesheet" href="{$filePrefix}/css/jquery-ui-1.10.3.custom/css/smoothness/jquery-ui-1.10.3.custom.css"/>
    <script type="text/javascript" src="{$teibpJS}"/>
    <script type="text/javascript">
      jQuery(document).ready(function() {
      $("html > head > title").text($("TEI > teiHeader > fileDesc > titleStmt > title:first").text());
      $.unblockUI();
      });
    </script>
  </xsl:template>

  <xsl:template name="css">
    <!-- the one hard-coded rule (for #tapas-ref-dialog) in this <style> element should probably be nuked, moving this one rule to tapasG.css. But we're not sure exactly what effect that will have, so we're holding off for now. -->
    <style type="text/css">
      #tapas-ref-dialog{
      z-index:1000;
      }
      <xsl:call-template name="rendition2style"/>
    </style>
  </xsl:template>

  <xsl:template name="rendition2style">
    <xsl:apply-templates select="//tei:rendition" mode="rendition2style"/>
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

  <xsl:template match="tei:pb">
    <xsl:variable name="pn">
      <xsl:number count="//tei:pb" level="any"/>
    </xsl:variable>
    <xsl:variable name="id">
      <xsl:choose>
        <xsl:when test="@xml:id">
          <xsl:value-of select="@xml:id"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="generate-id()"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$displayPageBreaks = true()">
        <span class="-teibp-pb">
          <xsl:call-template name="addID"/>
          <a class="-teibp-pageNum" data-tapas-n="{$pn}">
            <xsl:if test="@n">
              <xsl:attribute name="data-tei-n">
                <xsl:value-of select="@n"/>
              </xsl:attribute>
            </xsl:if>
          </a>
          <xsl:if test="@facs">
            <span class="-teibp-pbFacs">
              <a class="gallery-facs" rel="prettyPhoto[gallery1]">
                <xsl:attribute name="onclick">
                  <xsl:value-of select="concat('showFacs(',$apos,@n,$apos,',',$apos,@facs,$apos,',',$apos,$id,$apos,')')"/>
                </xsl:attribute>
                <img  alt="{$altTextPbFacs}" class="-teibp-thumbnail">
                  <xsl:attribute name="src">
                    <xsl:value-of select="@facs"/>
                  </xsl:attribute>
                </img>
              </a>
            </span>
          </xsl:if>
        </span>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy>
          <xsl:apply-templates select="@*"/>
          <xsl:attribute name="data-tapas-n"><xsl:value-of select="$pn"/></xsl:attribute>
          <xsl:apply-templates select="node()"/>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!--
   There are *no* <egXML> elements in our input data.
   So for now, we get to ignore them, as the call to
   xml-to-string makes it hard to debug this program
   in oXygen.
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
  -->

  <xsl:template name="tagUsage2style">
    <style type="text/css" id="tagusage-css">
      <xsl:for-each select="//tei:namespace[@name ='http://www.tei-c.org/ns/1.0']/tei:tagUsage">
        <xsl:value-of select="concat('&#x000a;',@gi,' { ')"/>
        <xsl:call-template name="tokenize">
          <xsl:with-param name="string" select="@render" />
        </xsl:call-template>
        <xsl:value-of select="'}&#x000a;'"/>
      </xsl:for-each>
    </style>
  </xsl:template>

  <xsl:template name="tokenize">
    <xsl:param name="string" />
    <xsl:param name="delimiter" select="' '" />
    <xsl:choose>
      <xsl:when test="$delimiter and contains($string, $delimiter)">
        <xsl:call-template name="grab-css">
          <xsl:with-param name="rendition-id" select="substring-after(substring-before($string, $delimiter),'#')" />
        </xsl:call-template>
        <xsl:text> </xsl:text>
        <xsl:call-template name="tokenize">
          <xsl:with-param name="string"
                          select="substring-after($string, $delimiter)" />
          <xsl:with-param name="delimiter" select="$delimiter" />
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="grab-css">
          <xsl:with-param name="rendition-id" select="substring-after($string,'#')"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="grab-css">
    <xsl:param name="rendition-id"/>
    <xsl:value-of select="normalize-space(key('IDs',$rendition-id)/text())"/>
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

  <xd:doc>
    <xd:desc>Template to drop insigificant whitespace nodes</xd:desc>
  </xd:doc>
  <xsl:template match="tei:choice/text()[normalize-space(.)='']"/>

  <!-- ***************************** -->
  <!-- handle contextual information -->
  <!-- ***************************** -->

  <xsl:template match="tei:nymList|tei:listOrg|tei:listPerson|tei:placeList|tei:nym|tei:org|tei:person|tei:place"/>

  <xd:doc>
    <xd:desc>Generate an entry for the separate "contextual information" block</xd:desc>
  </xd:doc>
  <xsl:template name="generateContextItem">
    <xsl:param name="ref"/>
    <xsl:param name="hashedRef"/>
    <xsl:variable name="uri" select="normalize-space($ref)"/>
    <xsl:variable name="scheme" select="substring-before($uri,':')"/>
    <xsl:variable name="fragID" select="substring-after($uri,'#')"/>
    <xsl:variable name="non-NCName-chars" select="concat(';?~ !@$%^&amp;*()+=[]&lt;&gt;,/\',$lcub,$rcub,$quot,$apos)"/>
    <xsl:choose>
      <xsl:when test="$scheme = ''  and  $fragID = ''  and
        translate( $uri, $non-NCName-chars, '') = $uri">
        <!-- looks like encoder probably forgot initial sharp symbol ("#") -->
        <xsl:comment> 1: </xsl:comment>
        <xsl:comment> uri=<xsl:value-of select="$uri"/> </xsl:comment>
        <xsl:comment> scheme=<xsl:value-of select="$scheme"/> </xsl:comment>
        <xsl:comment> fragID=<xsl:value-of select="$fragID"/> </xsl:comment>
        <xsl:if test="id( $uri )">
          <p class="contextualItem">
            <a id="{$hashedRef}"/>
            <xsl:apply-templates select="id( $uri )" mode="stripID"/>
          </p>
        </xsl:if>
      </xsl:when>
      <xsl:when test="$scheme = ''  and  $fragID != ''  and
        substring-before($uri,'#') = ''">
        <xsl:comment> 2: </xsl:comment>
        <xsl:comment> uri=<xsl:value-of select="$uri"/> </xsl:comment>
        <xsl:comment> scheme=<xsl:value-of select="$scheme"/> </xsl:comment>
        <xsl:comment> fragID=<xsl:value-of select="$fragID"/> </xsl:comment>
        <!-- just a bare name identifier, i.e. local -->
        <xsl:if test="id( $fragID )">
          <p class="contextualItem">
            <a id="{$hashedRef}"/>
            <xsl:apply-templates select="id( $fragID )" mode="stripID"/>
          </p>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <xsl:comment> 3: </xsl:comment>
        <xsl:comment> uri=<xsl:value-of select="$uri"/> </xsl:comment>
        <xsl:comment> scheme=<xsl:value-of select="$scheme"/> </xsl:comment>
        <xsl:comment> fragID=<xsl:value-of select="$fragID"/> </xsl:comment>
        <xsl:if test="document( $uri, $input )">
          <p class="contextualItem">
            <a id="{$hashedRef}"/>
            <xsl:apply-templates select="document( $uri, $input )" mode="stripID"/>
          </p>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="@*|*" mode="stripID">
    <xsl:copy>
      <xsl:apply-templates select="@*|*|text()" mode="stripID"/>
    </xsl:copy>
  </xsl:template>
  <!-- for <person> elements we want children in a specific order -->
  <xsl:template match="tei:person|tei:personGrp" mode="stripID">
    <xsl:apply-templates select="@*" mode="stripID"/>
    <xsl:apply-templates select="tei:persName" mode="stripID"/>
    <xsl:apply-templates select="tei:ab|tei:p" mode="stripID"/>
    <xsl:apply-templates select="tei:birth" mode="stripID"/>
    <xsl:apply-templates select="tei:death" mode="stripID"/>
    <xsl:apply-templates select="*
      [ not(
             self::tei:persName
          or self::tei:ab
          or self::tei:p
          or self::tei:birth
          or self::tei:death     ) ]" mode="stripID">
      <xsl:sort select="concat( local-name(.), @when, @from, @notBefore, @to, @notAfter )"/>
    </xsl:apply-templates>
  </xsl:template>
  <xsl:template match="@xml:id" mode="stripID"/>
  <xsl:template match="comment()|processing-instruction()" mode="stripID"/>

</xsl:stylesheet>
