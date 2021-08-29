<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="taskCheckInstall">
    <task name="/distribution/check-install" role="STANDALONE"/>
  </xsl:template>

  <xsl:template name="taskUpdateZStreamRepo">
    <xsl:if test="/submit/recipe/product_stream">
      <task name="/distribution/osci/update_repos" role="STANDALONE">
        <params>
          <param name="PRODUCT_STREAM">
            <xsl:attribute name="value"><xsl:value-of select="product_stream"/></xsl:attribute>
          </param>
        </params>
      </task>
    </xsl:if>
  </xsl:template>

  <xsl:template name="taskUpdateOS">
    <task name="/distribution/command" role="STANDALONE">
      <params>
        <param name="CMDS_TO_RUN">
          <xsl:attribute name="value">
            <xsl:choose>
              <xsl:when test="$distro_prior_to_8 = 'yes'">
                <xsl:text>yum update -y --skip-broken || exit 0</xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>dnf upgrade -y --skip-broken || exit 0</xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
        </param>
      </params>
    </task>
  </xsl:template>

  <xsl:template name="taskInstallComp">
    <task name="/distribution/command" role="STANDALONE">
      <params>
        <param name="CMDS_TO_RUN">
          <xsl:attribute name="value">
            <xsl:choose>
              <xsl:when test="$distro_prior_to_8 = 'yes'">
                <xsl:value-of select="concat('/root/brew_install.sh', ' ', /submit/recipe/install_params)"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="concat('python3 /root/component_management.py', ' ', /submit/recipe/install_params)"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
        </param>
      </params>
    </task>
  </xsl:template>

  <xsl:template name="taskKernelInstall">
    <xsl:if test="/submit/recipe/kernel_ver">
      <task name="/distribution/kernelinstall" role="STANDALONE">
        <params>
          <param name="KERNELARGVARIANT" value="up"/>
          <param name="KERNELARGNAME" value="kernel"/>
          <param name="KERNELARGVERSION">
            <xsl:attribute name="value"><xsl:value-of select="kernel_ver"/></xsl:attribute>
          </param>
        </params>
      </task>
    </xsl:if>
  </xsl:template>

  <xsl:template name="taskInstallMngtTools">
    <xsl:if test="$distro_prior_to_8 = 'yes'">
      <task name="/distribution/command" role="STANDALONE">
        <params>
          <param name="CMDS_TO_RUN" value="yum install -y libvirt libguestfs libguestfs-tools libguestfs-winsupport python-libguestfs"/>
        </params>
      </task>
    </xsl:if>
  </xsl:template>

  <xsl:template name="taskSetupNMBridge">
    <xsl:if test="$distro_prior_to_8 = 'no'">
      <task name="/distribution/command" role="STANDALONE">
        <params>
          <param name="CMDS_TO_RUN" value="/root/setup_bridge.sh"/>
        </params>
      </task>
    </xsl:if>
  </xsl:template>

  <xsl:template name="taskReboot">
    <task name="/distribution/utils/reboot" role="STANDALONE"/>
  </xsl:template>

</xsl:stylesheet>
