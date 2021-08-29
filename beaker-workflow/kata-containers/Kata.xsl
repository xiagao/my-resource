<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:include href="../Common.xsl"/>
  <xsl:include href="../TaskLibs.xsl"/>
  <xsl:template match="/submit/recipe">
    <recipeSet>
      <recipe role="RECIPE_MEMBERS">
        <autopick random="false"/>
        <xsl:apply-templates select="repos"/>
        <xsl:apply-templates select="packages"/>
        <xsl:apply-templates select="machine"/>
        <xsl:apply-templates select="ks_append"/>
        <xsl:call-template name="taskCheckInstall"/>
        <task name="/distribution/command" role="STANDALONE">
          <params>
            <param name="CMDS_TO_RUN">
              <xsl:attribute name="value">
                <xsl:value-of select="concat('/root/kata-tests/installation.sh', ' ', /submit/recipe/install_params)"/>
              </xsl:attribute>
            </param>
          </params>
        </task>
        <task name="/distribution/command" role="STANDALONE">
          <params>
            <param name="CMDS_TO_RUN" value="/root/kata-tests/sanity.sh"/>
          </params>
        </task>
        <xsl:if test="/submit/recipe/integration != 'none'">
          <task name="/distribution/command" role="STANDALONE">
            <params>
              <param name="CMDS_TO_RUN">
                <xsl:attribute name="value">
                  <xsl:value-of select="concat('/root/kata-tests/integration_', /submit/recipe/integration, '.sh')"/>
                </xsl:attribute>
              </param>
            </params>
          </task>
        </xsl:if>
        <xsl:apply-templates select="reservetime"/>
      </recipe>
    </recipeSet>
  </xsl:template>
</xsl:stylesheet>
