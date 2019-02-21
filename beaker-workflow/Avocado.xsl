<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:include href="Common.xsl"/>
  <xsl:template match="/submit/recipe">
    <recipeSet>
      <recipe role="RECIPE_MEMBERS">
        <autopick random="false"/>
        <xsl:apply-templates select="repos"/>
        <xsl:apply-templates select="packages"/>
        <xsl:apply-templates select="machine"/>
        <xsl:apply-templates select="ks_append"/>
        <task name="/distribution/check-install" role="STANDALONE"/>
       <xsl:if test="$distro_prior_to_8 = 'yes'">
          <task name="/distribution/command" role="STANDALONE">
            <params>
              <param name="CMDS_TO_RUN" value="yum update -y --skip-broken || exit 0"/>
            </params>
          </task>
        </xsl:if>
        <task name="/distribution/command" role="STANDALONE">
          <params>
            <param name="CMDS_TO_RUN">
              <xsl:attribute name="value">
                <xsl:choose>
                  <xsl:when test="$distro_prior_to_8 = 'yes'">
                    <xsl:value-of select="concat('/root/brew_install.sh', ' ', install_params)"/>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="concat('python3 /root/component_management.py', ' ', install_params)"/>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:attribute>
            </param>
          </params>
        </task>
        <xsl:if test="$distro_prior_to_8 = 'yes'">
          <task name="/distribution/command" role="STANDALONE">
            <params>
              <param name="CMDS_TO_RUN" value="yum install -y libvirt libguestfs libguestfs-tools libguestfs-winsupport python-libguestfs"/>
            </params>
          </task>
        </xsl:if>
        <xsl:if test="$distro_prior_to_8 = 'no'">
          <task name="/distribution/command" role="STANDALONE">
            <params>
              <param name="CMDS_TO_RUN" value="/root/setup_bridge.sh"/>
            </params>
          </task>
        </xsl:if>
        <task name="/distribution/utils/reboot" role="STANDALONE"/>
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
        <xsl:apply-templates select="reservetime"/>
      </recipe>
    </recipeSet>
  </xsl:template>
</xsl:stylesheet>
