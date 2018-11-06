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
        <task name="/distribution/install" role="STANDALONE"/>
        <task name="/distribution/command" role="STANDALONE">
          <params>
            <param name="CMDS_TO_RUN">
              <xsl:attribute name="value">
                <xsl:choose>
                  <xsl:when test="$distro_prior_to_8 = 'yes'">
                    <xsl:text>yum update -y --skip-broken || exit 0</xsl:text>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:text>dnf update -y --skip-broken || exit 0</xsl:text>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:attribute>
            </param>
          </params>
        </task>
        <task name="/distribution/command" role="STANDALONE">
          <params>
            <param name="CMDS_TO_RUN">
              <xsl:attribute name="value"><xsl:value-of select="concat('/root/brew_install.sh', ' ', qemu_ver)"/></xsl:attribute>
            </param>
          </params>
        </task>
        <task name="/distribution/command" role="STANDALONE">
          <params>
            <param name="CMDS_TO_RUN">
              <xsl:attribute name="value">
                <xsl:choose>
                  <xsl:when test="$distro_prior_to_8 = 'yes'">
                    <xsl:text>yum install -y libvirt libguestfs libguestfs-tools libguestfs-winsupport python-libguestfs</xsl:text>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:text>dnf install -y libvirt libguestfs libguestfs-tools libguestfs-winsupport python-libguestfs</xsl:text>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:attribute>
            </param>
          </params>
        </task>
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
