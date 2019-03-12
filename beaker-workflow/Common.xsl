<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:variable name="distro_prior_to_8">
    <xsl:choose>
      <xsl:when test="contains(/submit/recipe/machine/@distro, 'RHEL-6')">
        <xsl:value-of select="'yes'"/>
      </xsl:when>
      <xsl:when test="contains(/submit/recipe/machine/@distro, 'RHEL-7')">
        <xsl:value-of select="'yes'"/>
      </xsl:when>
      <xsl:when test="contains(/submit/recipe/machine/@distro, 'RHEL-ALT-7')">
        <xsl:value-of select="'yes'"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="'no'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes" cdata-section-elements="ks_append"/>
  <xsl:template match="/submit">
    <job>
      <xsl:apply-templates select="whiteboard"/>
      <xsl:apply-templates select="recipe"/>
    </job>
  </xsl:template>
  <xsl:template match="/submit/whiteboard">
    <whiteboard>
      <xsl:value-of select="."/>
    </whiteboard>
  </xsl:template>
  <xsl:template match="/submit/recipe/repos">
    <repos>
      <xsl:for-each select="repo">
        <repo>
          <xsl:attribute name="name"><xsl:value-of select="concat('extra-repo', position())"/></xsl:attribute>
          <xsl:attribute name="url"><xsl:value-of select="."/></xsl:attribute>
        </repo>
      </xsl:for-each>
    </repos>
  </xsl:template>
  <xsl:template match="/submit/recipe/packages">
    <packages>
      <xsl:for-each select="package">
        <package>
          <xsl:attribute name="name"><xsl:value-of select="."/></xsl:attribute>
        </package>
      </xsl:for-each>
    </packages>
  </xsl:template>
  <xsl:template match="/submit/recipe/machine">
    <hostRequires>
      <xsl:choose>
        <xsl:when test="string-length(@hostname) &gt; 0">
          <hostname op="=">
            <xsl:attribute name="value"><xsl:value-of select="@hostname"/></xsl:attribute>
          </hostname>
        </xsl:when>
        <xsl:otherwise>
          <and>
            <arch op="=">
              <xsl:attribute name="value"><xsl:value-of select="@arch"/></xsl:attribute>
            </arch>
            <hypervisor op="=" value=""/>
            <system_type op="=" value="Machine"/>
            <xsl:for-each select="../host_filters/filter">
              <xsl:choose>
                <xsl:when test=". = 'intel'">
                  <key_value key="CPUFLAGS" op="=" value="vmx"/>
                </xsl:when>
                <xsl:when test=". = 'amd'">
                  <key_value key="CPUFLAGS" op="=" value="svm"/>
                </xsl:when>
                <xsl:when test=". = 'power8'">
                  <key_value key="CPUMODEL" op="like" value="POWER8%"/>
                </xsl:when>
                <xsl:when test=". = 'power9'">
                  <key_value key="CPUMODEL" op="like" value="POWER9%"/>
                  <!-- requires model greater than or equal to DD2 -->
                  <key_value key="CPUMODELNUMBER" op=">=" value="5116417"/>
                </xsl:when>
                <xsl:when test=". = 'min-cores-8'">
                  <cpu>
                    <cores op=">=" value="8"/>
                  </cpu>
                </xsl:when>
                <xsl:when test=". = 'min-cores-4'">
                  <cpu>
                    <cores op=">=" value="4"/>
                  </cpu>
                </xsl:when>
                <xsl:when test=". = 'min-processors-8'">
                  <key_value key="PROCESSORS" op="&gt;=" value="8"/>
                </xsl:when>
                <xsl:when test=". = 'pek'">
                  <hostlabcontroller op="=" value="lab-01.rhts.eng.pek2.redhat.com"/>
                </xsl:when>
                <xsl:when test=". = 'bos'">
                  <hostlabcontroller op="=" value="lab-02.rhts.eng.bos.redhat.com"/>
                </xsl:when>
                <xsl:when test=". = 'min-mem-4g'">
                  <memory op=">=" value="4096"/>
                </xsl:when>
                <xsl:when test=". = 'min-mem-8g'">
                  <memory op=">=" value="8192"/>
                </xsl:when>
                <xsl:when test=". = 'min-mem-64g'">
                  <memory op=">=" value="65536"/>
                </xsl:when>
                <xsl:when test=". = 'min-disk-256g'">
                  <key_value key="DISKSPACE" op=">=" value="256000"/>
                </xsl:when>
                <xsl:when test=". = 'min-disk-150g'">
                  <key_value key="DISKSPACE" op=">=" value="150000"/>
                </xsl:when>
                <xsl:when test=". = 'nic-driver-e1000'">
                  <device op="like" driver="e1000%"/>
                </xsl:when>
                <xsl:otherwise/>
              </xsl:choose>
            </xsl:for-each>
          </and>
          <xsl:for-each select="document(@extra_filter)/hostRequires/*">
            <xsl:copy-of select="."/>
          </xsl:for-each>
        </xsl:otherwise>
      </xsl:choose>
    </hostRequires>
    <distroRequires>
      <and>
        <distro_name op="=">
          <xsl:attribute name="value"><xsl:value-of select="@distro"/></xsl:attribute>
        </distro_name>
        <distro_variant op="=">
          <xsl:attribute name="value">
            <xsl:choose>
              <xsl:when test="$distro_prior_to_8 = 'yes'">
                <xsl:text>Server</xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>BaseOS</xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
        </distro_variant>
        <distro_arch op="=">
          <xsl:attribute name="value"><xsl:value-of select="@arch"/></xsl:attribute>
        </distro_arch>
      </and>
    </distroRequires>
  </xsl:template>
  <xsl:template match="/submit/recipe/ks_append">
    <ks_appends>
      <ks_append>
        <xsl:value-of select="document(.)/ks"/>
      </ks_append>
    </ks_appends>
  </xsl:template>
  <xsl:template match="/submit/recipe/reservetime">
    <xsl:if test=". &gt; 0">
      <task name="/distribution/reservesys" role="STANDALONE">
        <params>
          <param name="RESERVE_IF_FAIL" value="True"/>
          <param name="RESERVETIME">
            <xsl:attribute name="value"><xsl:value-of select=". &#42; 3600"/></xsl:attribute>
          </param>
        </params>
      </task>
    </xsl:if>
  </xsl:template>
</xsl:stylesheet>
