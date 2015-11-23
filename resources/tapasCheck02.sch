<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://www.ascc.net/xml/schematron">  
  <title>TAPAS generic will-work-OK tests</title>
  <ns uri="http://www.tei-c.org/ns/1.0" prefix="tei"/>

  <!-- named "tapasCheck02", as this is intended as the 2nd check -->
  <!-- on TEI file ingestion into TAPAS. The first check is named "isTEI.sch" -->
  <!-- because it tests to see if the XML file is actually TEI at all-->

  <p>Written 2014-04-11 by Syd Bauman for TAPAS. Copyleft.</p>
  <p>Updated 2014-04-12 by Syd Bauman such that the context is no
  longer attribute::rendition, but rather an element. This was needed
  because 'skeleton1-5.xsl' produces XSLT that never files the rule if
  the context is an attribute. This occured with any of my available
  versions of the program: the original from
  http://xml.ascc.net/schematron/1.5/skeleton1-5.xsl, the Syncro
  improved one in
  /Applications/oxygen/frameworks/schematron/impl/skeleton1-5.xsl, or
  the one I worked on that is in this directory. In all cases, a
  template that matches the context (attribute::rendition) is
  generated, but no execution path to get to it exists, so it never
  gets fired.</p>
  <p>Updated 2014-04-18 by Syd Bauman to make use of role= attribute,
  as our skeleton1-5.xsl now processes those. Also tweaked
  wording.</p>
  <p>Updated 2014-04-18 by Syd Bauman to fire only once per TEI file,
  rather than once for every infraction. (We test from the vantage of
  ＜text＞, ＜facsimile＞, ＜sourceDoc＞, or ＜fsdDecl＞ so as to
  avoid flagging any teiHeader/@rendition; this means we miss the
  TEI/@rendition or the teiCorpus/@rendition. Hmmm...</p>
  
  <ns prefix="tei" uri="http://www.tei-c.org/ns/1.0"/>

  <pattern name="rendition-has-colon">
    <rule context="tei:text|tei:fsdDecl|tei:facsimile|tei:sourceDoc">
      <report test="contains( .//@rendition,':')" role="warning">You have a @rendition that is invalid because it contains a colon. This will not stop your document from loading, but it probably won't look right.</report>
      <report test="
                    contains( .//@rendition,'azimuth:')  or  contains( normalize-space( .//@rendition ),'azimuth :')
                 or contains( .//@rendition,'background:')  or  contains( normalize-space( .//@rendition ),'background :')
                 or contains( .//@rendition,'background-attachment:')  or  contains( normalize-space( .//@rendition ),'background-attachment :')
                 or contains( .//@rendition,'background-color:')  or  contains( normalize-space( .//@rendition ),'background-color :')
                 or contains( .//@rendition,'background-image:')  or  contains( normalize-space( .//@rendition ),'background-image :')
                 or contains( .//@rendition,'background-position:')  or  contains( normalize-space( .//@rendition ),'background-position :')
                 or contains( .//@rendition,'background-repeat:')  or  contains( normalize-space( .//@rendition ),'background-repeat :')
                 or contains( .//@rendition,'border:')  or  contains( normalize-space( .//@rendition ),'border :')
                 or contains( .//@rendition,'border-collapse:')  or  contains( normalize-space( .//@rendition ),'border-collapse :')
                 or contains( .//@rendition,'border-color:')  or  contains( normalize-space( .//@rendition ),'border-color :')
                 or contains( .//@rendition,'border-spacing:')  or  contains( normalize-space( .//@rendition ),'border-spacing :')
                 or contains( .//@rendition,'border-style:')  or  contains( normalize-space( .//@rendition ),'border-style :')
                 or contains( .//@rendition,'border-top:')  or  contains( normalize-space( .//@rendition ),'border-top :')
                 or contains( .//@rendition,'border-top-color:')  or  contains( normalize-space( .//@rendition ),'border-top-color :')
                 or contains( .//@rendition,'border-top-style:')  or  contains( normalize-space( .//@rendition ),'border-top-style :')
                 or contains( .//@rendition,'border-top-width:')  or  contains( normalize-space( .//@rendition ),'border-top-width :')
                 or contains( .//@rendition,'border-width:')  or  contains( normalize-space( .//@rendition ),'border-width :')
                 or contains( .//@rendition,'bottom:')  or  contains( normalize-space( .//@rendition ),'bottom :')
                 or contains( .//@rendition,'caption-side:')  or  contains( normalize-space( .//@rendition ),'caption-side :')
                 or contains( .//@rendition,'clear:')  or  contains( normalize-space( .//@rendition ),'clear :')
                 or contains( .//@rendition,'clip:')  or  contains( normalize-space( .//@rendition ),'clip :')
                 or contains( .//@rendition,'color:')  or  contains( normalize-space( .//@rendition ),'color :')
                 or contains( .//@rendition,'content:')  or  contains( normalize-space( .//@rendition ),'content :')
                 or contains( .//@rendition,'counter-increment:')  or  contains( normalize-space( .//@rendition ),'counter-increment :')
                 or contains( .//@rendition,'counter-reset:')  or  contains( normalize-space( .//@rendition ),'counter-reset :')
                 or contains( .//@rendition,'cue:')  or  contains( normalize-space( .//@rendition ),'cue :')
                 or contains( .//@rendition,'cue-after:')  or  contains( normalize-space( .//@rendition ),'cue-after :')
                 or contains( .//@rendition,'cue-before:')  or  contains( normalize-space( .//@rendition ),'cue-before :')
                 or contains( .//@rendition,'cursor:')  or  contains( normalize-space( .//@rendition ),'cursor :')
                 or contains( .//@rendition,'direction:')  or  contains( normalize-space( .//@rendition ),'direction :')
                 or contains( .//@rendition,'display:')  or  contains( normalize-space( .//@rendition ),'display :')
                 or contains( .//@rendition,'elevation:')  or  contains( normalize-space( .//@rendition ),'elevation :')
                 or contains( .//@rendition,'empty-cells:')  or  contains( normalize-space( .//@rendition ),'empty-cells :')
                 or contains( .//@rendition,'float:')  or  contains( normalize-space( .//@rendition ),'float :')
                 or contains( .//@rendition,'font:')  or  contains( normalize-space( .//@rendition ),'font :')
                 or contains( .//@rendition,'font-family:')  or  contains( normalize-space( .//@rendition ),'font-family :')
                 or contains( .//@rendition,'font-size:')  or  contains( normalize-space( .//@rendition ),'font-size :')
                 or contains( .//@rendition,'font-size-adjust:')  or  contains( normalize-space( .//@rendition ),'font-size-adjust :')
                 or contains( .//@rendition,'font-stretch:')  or  contains( normalize-space( .//@rendition ),'font-stretch :')
                 or contains( .//@rendition,'font-style:')  or  contains( normalize-space( .//@rendition ),'font-style :')
                 or contains( .//@rendition,'font-variant:')  or  contains( normalize-space( .//@rendition ),'font-variant :')
                 or contains( .//@rendition,'font-weight:')  or  contains( normalize-space( .//@rendition ),'font-weight :')
                 or contains( .//@rendition,'height:')  or  contains( normalize-space( .//@rendition ),'height :')
                 or contains( .//@rendition,'left:')  or  contains( normalize-space( .//@rendition ),'left :')
                 or contains( .//@rendition,'letter-spacing:')  or  contains( normalize-space( .//@rendition ),'letter-spacing :')
                 or contains( .//@rendition,'line-height:')  or  contains( normalize-space( .//@rendition ),'line-height :')
                 or contains( .//@rendition,'list-style:')  or  contains( normalize-space( .//@rendition ),'list-style :')
                 or contains( .//@rendition,'list-style-image:')  or  contains( normalize-space( .//@rendition ),'list-style-image :')
                 or contains( .//@rendition,'list-style-position:')  or  contains( normalize-space( .//@rendition ),'list-style-position :')
                 or contains( .//@rendition,'list-style-type:')  or  contains( normalize-space( .//@rendition ),'list-style-type :')
                 or contains( .//@rendition,'margin:')  or  contains( normalize-space( .//@rendition ),'margin :')
                 or contains( .//@rendition,'margin-top:')  or  contains( normalize-space( .//@rendition ),'margin-top :')
                 or contains( .//@rendition,'marker-offset:')  or  contains( normalize-space( .//@rendition ),'marker-offset :')
                 or contains( .//@rendition,'marks:')  or  contains( normalize-space( .//@rendition ),'marks :')
                 or contains( .//@rendition,'max-height:')  or  contains( normalize-space( .//@rendition ),'max-height :')
                 or contains( .//@rendition,'max-width:')  or  contains( normalize-space( .//@rendition ),'max-width :')
                 or contains( .//@rendition,'min-height:')  or  contains( normalize-space( .//@rendition ),'min-height :')
                 or contains( .//@rendition,'min-width:')  or  contains( normalize-space( .//@rendition ),'min-width :')
                 or contains( .//@rendition,'orphans:')  or  contains( normalize-space( .//@rendition ),'orphans :')
                 or contains( .//@rendition,'outline:')  or  contains( normalize-space( .//@rendition ),'outline :')
                 or contains( .//@rendition,'outline-color:')  or  contains( normalize-space( .//@rendition ),'outline-color :')
                 or contains( .//@rendition,'outline-style:')  or  contains( normalize-space( .//@rendition ),'outline-style :')
                 or contains( .//@rendition,'outline-width:')  or  contains( normalize-space( .//@rendition ),'outline-width :')
                 or contains( .//@rendition,'overflow:')  or  contains( normalize-space( .//@rendition ),'overflow :')
                 or contains( .//@rendition,'padding:')  or  contains( normalize-space( .//@rendition ),'padding :')
                 or contains( .//@rendition,'padding-top:')  or  contains( normalize-space( .//@rendition ),'padding-top :')
                 or contains( .//@rendition,'page:')  or  contains( normalize-space( .//@rendition ),'page :')
                 or contains( .//@rendition,'page-break-after:')  or  contains( normalize-space( .//@rendition ),'page-break-after :')
                 or contains( .//@rendition,'page-break-before:')  or  contains( normalize-space( .//@rendition ),'page-break-before :')
                 or contains( .//@rendition,'page-break-inside:')  or  contains( normalize-space( .//@rendition ),'page-break-inside :')
                 or contains( .//@rendition,'pause:')  or  contains( normalize-space( .//@rendition ),'pause :')
                 or contains( .//@rendition,'pause-after:')  or  contains( normalize-space( .//@rendition ),'pause-after :')
                 or contains( .//@rendition,'pause-before:')  or  contains( normalize-space( .//@rendition ),'pause-before :')
                 or contains( .//@rendition,'pitch:')  or  contains( normalize-space( .//@rendition ),'pitch :')
                 or contains( .//@rendition,'pitch-range:')  or  contains( normalize-space( .//@rendition ),'pitch-range :')
                 or contains( .//@rendition,'play-during:')  or  contains( normalize-space( .//@rendition ),'play-during :')
                 or contains( .//@rendition,'position:')  or  contains( normalize-space( .//@rendition ),'position :')
                 or contains( .//@rendition,'quotes:')  or  contains( normalize-space( .//@rendition ),'quotes :')
                 or contains( .//@rendition,'richness:')  or  contains( normalize-space( .//@rendition ),'richness :')
                 or contains( .//@rendition,'right:')  or  contains( normalize-space( .//@rendition ),'right :')
                 or contains( .//@rendition,'size:')  or  contains( normalize-space( .//@rendition ),'size :')
                 or contains( .//@rendition,'speak:')  or  contains( normalize-space( .//@rendition ),'speak :')
                 or contains( .//@rendition,'speak-header:')  or  contains( normalize-space( .//@rendition ),'speak-header :')
                 or contains( .//@rendition,'speak-numeral:')  or  contains( normalize-space( .//@rendition ),'speak-numeral :')
                 or contains( .//@rendition,'speak-punctuation:')  or  contains( normalize-space( .//@rendition ),'speak-punctuation :')
                 or contains( .//@rendition,'speech-rate:')  or  contains( normalize-space( .//@rendition ),'speech-rate :')
                 or contains( .//@rendition,'stress:')  or  contains( normalize-space( .//@rendition ),'stress :')
                 or contains( .//@rendition,'table-layout:')  or  contains( normalize-space( .//@rendition ),'table-layout :')
                 or contains( .//@rendition,'text-align:')  or  contains( normalize-space( .//@rendition ),'text-align :')
                 or contains( .//@rendition,'text-decoration:')  or  contains( normalize-space( .//@rendition ),'text-decoration :')
                 or contains( .//@rendition,'text-indent:')  or  contains( normalize-space( .//@rendition ),'text-indent :')
                 or contains( .//@rendition,'text-shadow:')  or  contains( normalize-space( .//@rendition ),'text-shadow :')
                 or contains( .//@rendition,'text-transform:')  or  contains( normalize-space( .//@rendition ),'text-transform :')
                 or contains( .//@rendition,'top:')  or  contains( normalize-space( .//@rendition ),'top :')
                 or contains( .//@rendition,'unicode-bidi:')  or  contains( normalize-space( .//@rendition ),'unicode-bidi :')
                 or contains( .//@rendition,'vertical-align:')  or  contains( normalize-space( .//@rendition ),'vertical-align :')
                 or contains( .//@rendition,'visibility:')  or  contains( normalize-space( .//@rendition ),'visibility :')
                 or contains( .//@rendition,'voice-family:')  or  contains( normalize-space( .//@rendition ),'voice-family :')
                 or contains( .//@rendition,'volume:')  or  contains( normalize-space( .//@rendition ),'volume :')
                 or contains( .//@rendition,'white-space:')  or  contains( normalize-space( .//@rendition ),'white-space :')
                 or contains( .//@rendition,'widows:')  or  contains( normalize-space( .//@rendition ),'widows :')
                 or contains( .//@rendition,'width:')  or  contains( normalize-space( .//@rendition ),'width :')
                 or contains( .//@rendition,'word-spacing:')  or  contains( normalize-space( .//@rendition ),'word-spacing :')
                 or contains( .//@rendition,'z-index:')  or  contains( normalize-space( .//@rendition ),'z-index :')
		 " role="info">
        It looks like you are trying to put CSS directly into a @rendition attribute, which is not valid TEI. The value of @rendition sould be a pointer to a ＜rendition＞ element, which may contain the CSS. To use CSS directly on an attribute, use the @style attribute.
      </report>
    </rule>
  </pattern>

  <pattern name="title-in-name">
    <rule context="/">
      <report test="//tei:persName/tei:title" role="warning">There is at least one ＜persName＞ element that has a child ＜title＞ element inside it. This is not technically invalid, but it is most likely that you intended ＜roleName＞, not ＜title＞.</report>
    </rule>
  </pattern>

</schema>
