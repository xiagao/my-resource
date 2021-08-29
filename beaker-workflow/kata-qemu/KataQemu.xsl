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
        <xsl:call-template name="taskUpdateZStreamRepo"/>
        <xsl:call-template name="taskUpdateOS"/>
        <xsl:call-template name="taskInstallComp"/>
        <xsl:call-template name="taskInstallMngtTools"/>
        <xsl:call-template name="taskSetupNMBridge"/>
        <xsl:call-template name="taskReboot"/>
        <task name="/virt/Durations/autotest-upstream" role="STANDALONE">
          <params>
            <param name="PYTHON_CMD">
              <xsl:attribute name="value"><xsl:value-of select="task_cmd"/></xsl:attribute>
            </param>
            <xsl:if test="string-length(env_opts) &gt; 0">
              <param name="BOOTSTRAP_PARAMS">
                <xsl:attribute name="value"><xsl:value-of select="env_opts"/></xsl:attribute>
              </param>
            </xsl:if>
            <param name="JUNIT_XML_NAME" value="Result.xml"/>
          </params>
        </task>
        <!--
        <task name="/distribution/command" role="STANDALONE">
          <params>
            <param name="CMDS_TO_RUN" value="git clone https://gitlab.cee.redhat.com/xuhan/kata-tests.git /root/kata-tests &amp;&amp; /root/kata-tests/integration_qemu.sh"/>
          </params>
        </task>
        -->
        <xsl:apply-templates select="reservetime"/>
      </recipe>
    </recipeSet>
  </xsl:template>
</xsl:stylesheet>
