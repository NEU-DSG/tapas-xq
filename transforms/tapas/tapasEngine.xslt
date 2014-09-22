<?xml version="1.0" encoding="UTF-8"?>
<!-- Copyleft 2013 Syd Bauman -->
<!-- For complete copyright notice see near bottom of file. -->
<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:tapas="http://www.wheatoncollege.edu/TAPAS/1.0"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:ixsl="http://saxonica.com/ns/interactiveXSLT"
  xmlns:js="http://saxonica.com/ns/globalJS"
  xmlns:prop="http://saxonica.com/ns/html-property"
  xmlns:style="http://saxonica.com/ns/html-style-property"
  xmlns:html="http://www.w3.org/1999/xhtml"
  exclude-result-prefixes="xsl tapas dc tei ixsl js prop style html"
  extension-element-prefixes="ixsl">

  <xsl:output method="html" indent="yes"/>
  
  <!-- we presume there is only 1 root TEI, i.e. no corpus, no -->
  <!-- multiple roots (ill-formed for XML 1.X) -->
  <xsl:template match="/">
    <xsl:apply-templates select="tei:TEI"/>
  </xsl:template>
  
  <xsl:template match="tei:TEI">
    <xsl:result-document href="#center" method="ixsl:replace-content">
      <p>Journey to the center of the document</p>
      <p>Click me.</p>
    </xsl:result-document>
  </xsl:template>
  
  <xsl:template match="html:p" mode="ixsl:onmouseover">
    <xsl:for-each select="//html:div[@id='toolTip1']">
      <ixsl:set-attribute name="style:left" select="concat(ixsl:get(ixsl:event(), 'clientX') + 30, 'px')"/>
      <ixsl:set-attribute name="style:top" select="concat(ixsl:get(ixsl:event(), 'clientY') - 15, 'px')"/>
      <ixsl:set-attribute name="style:visibility" select="'visible'"/>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="html:p" mode="ixsl:onmouseout">
    <xsl:for-each select="//html:div[@id='toolTip1']">
      <ixsl:set-attribute name="style:visibility" select="'hidden'"/>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:template match="html:p[2]" mode="ixsl:onclick">
    <xsl:result-document href="#bottom" method="ixsl:append-content">
      <p>ADDED p#<xsl:value-of select="count(ixsl:page()//*[@id='bottom']//html:p)+1"/></p>
    </xsl:result-document>
  </xsl:template>

  <!-- 
    Copyright 2013 Syd Bauman.
    
    This file is part of TAPAS.

    TAPAS is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Foobar is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Foobar. If not, see <http://www.gnu.org/licenses/>.
  -->

</xsl:stylesheet>
