<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes" version="1.0" encoding="utf-8"/>

  <xsl:param name="WorkingCopy" select="''"/>

  <xsl:template match="/test-run">
    <testsuites tests="{@testcasecount}" failures="{@failed}" disabled="{@skipped}" time="{@duration}">
      <xsl:apply-templates/>
    </testsuites>
  </xsl:template>

  <xsl:template match="test-suite">
    <xsl:if test="test-case">
      <testsuite tests="{@testcasecount}" time="{@duration}" errors="{@testcasecount - @passed - @skipped - @failed}" failures="{@failed}" skipped="{@skipped}" timestamp="{@start-time}">
        <xsl:attribute name="name">
          <xsl:for-each select="ancestor-or-self::test-suite[@type='TestSuite']/@name">
            <xsl:value-of select="concat(., '.')"/>
          </xsl:for-each>
        </xsl:attribute>
        <xsl:apply-templates select="test-case"/>
      </testsuite>
      <xsl:apply-templates select="test-suite"/>
    </xsl:if>
    <xsl:if test="not(test-case)">
      <xsl:apply-templates/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="test-case">
    <testcase name="{@name}" assertions="{@asserts}" time="{@duration}" status="{@result}" classname="{@classname}">
      <xsl:if test="@result = 'Skipped' or @result = 'Inconclusive'">
        <xsl:variable name="skipType">
          <xsl:choose>
            <xsl:when test="@label">
              <xsl:value-of select="@label"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="@result"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <skipped>
          <xsl:text disable-output-escaping="yes">&lt;![CDATA[</xsl:text>
          <xsl:text>skip type: </xsl:text><xsl:value-of select="$skipType"/>
          <xsl:apply-templates select="./reason"/>
          <xsl:apply-templates select="./output"/>
          <xsl:text disable-output-escaping="yes">]]&gt;</xsl:text>
        </skipped>
      </xsl:if>
      
      <xsl:apply-templates select="./failure"/>
      <xsl:apply-templates select="./attachments"/>
    </testcase>
  </xsl:template>

  <xsl:template match="attachments">
    <system-out>
      <xsl:apply-templates/>
    </system-out>
  </xsl:template>

  <xsl:template match="attachment">
    <xsl:variable name="path">
      <xsl:variable name="trimmedPath" select="substring-after(./filePath, $WorkingCopy)"/>
      <xsl:choose>
        <xsl:when test="$trimmedPath">
          <xsl:value-of select="$trimmedPath"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="./filePath"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    [[ATTACHMENT|<xsl:value-of select="translate($path, '\', '/')"/>]]
  </xsl:template>

  <xsl:template match="test-case/failure">
    <xsl:variable name="failureType">
      <xsl:choose>
        <xsl:when test="../@label='Error'">error</xsl:when>
        <xsl:otherwise>failure</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:element name="{$failureType}">
      <xsl:text disable-output-escaping="yes">&lt;![CDATA[</xsl:text>
      <xsl:apply-templates/>
      <xsl:apply-templates select="../output"/>
      <xsl:text disable-output-escaping="yes">]]&gt;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="test-case/failure/message">
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="test-case/failure/stack-trace">
    <xsl:text>&#13;&#10;&#13;&#10;-- stack trace ------------------------&#13;&#10;</xsl:text>
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="test-case/reason/message">
    <xsl:text>&#13;&#10;</xsl:text>
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="test-case/output">
    <xsl:text>&#13;&#10;&#13;&#10;-- output ------------------------&#13;&#10;</xsl:text>
    <xsl:value-of select="."/>
  </xsl:template>

  <!-- loose text will cause parsing errors in GitLab -->
  <xsl:template match="text()" />
</xsl:stylesheet>
