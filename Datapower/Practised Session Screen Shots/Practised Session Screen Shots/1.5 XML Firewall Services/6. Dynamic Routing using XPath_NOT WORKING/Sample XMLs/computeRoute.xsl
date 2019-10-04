<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:dp="http://www.datapower.com/extensions"
   xmlns:dpconfig="http://www.datapower.com/param/config"
   exclude-result-prefixes="dp dpconfig"
   extension-element-prefixes="dp"
   version="1.0">
   
   <!-- 
     This stylesheet assigns dynamic routing information based
     on the inbound URI and and a routing file named route.xml.
     The routing file entry with the *longest* match to the
     inbound URI will be chosen.  (Since wild-cards are allowed,
     there could be multiple candidate matches).  If there are
     no matches, the request is rejected.
     -->

   <dp:summary xmlns="">
      <operation>xform</operation>
      <description>
         Determine a dynamic route based on the inbound URI and 
         a route file, specified as an input parameter.
      </description>
   </dp:summary>

   <xsl:param name="dpconfig:RouteFile" select="'routes.xml'"/>
   <dp:param name="dpconfig:RouteFile" type="dmString" xmlns="">
      <display>Route File</display>
      <description>
         Provide the relative path to a route file that
         determines the location of downstream services.
         The default is routes.xml.
      </description>
      <default>routes.xml</default>
   </dp:param>

   <xsl:variable name="domain"   select="dp:variable('var://service/domain-name')"/>
   <xsl:variable name="category" select="concat('route-',$domain)"/>
   
   <xsl:template match="/">
      <xsl:variable name="routes" select="document($dpconfig:RouteFile)/routes"/>
      <xsl:variable name="uri" select="dp:variable('var://service/URI')"/>
      
      <!-- 
        Collect all service elements with a uri attribute that matches the
        beginning of the inbound URI. 
        -->
      <xsl:variable name="service-matches" select="$routes/service[starts-with($uri, @uri)]"/>

      <!-- Reject if there are no matches.  Log if there are multiple ones. -->
      <xsl:choose>
         <xsl:when test="1 &gt; count($service-matches)">
            <xsl:message dp:priority="warn" dp:type="{$category}">
               Route match failure.
               Inbound URI = <xsl:value-of select="$uri"/>
            </xsl:message>      
            <dp:reject>
               No URI match for <xsl:value-of select="$uri"/> 
               using route file <xsl:value-of select="$dpconfig:RouteFile"/> 
            </dp:reject>
         </xsl:when>
         <xsl:when test="1 &lt; count($service-matches)">
            <xsl:message dp:priority="info" dp:type="{$category}">
               Found <xsl:value-of select="count($service-matches)"/> URI matches.
               Matching most specific one.
            </xsl:message>
         </xsl:when>
      </xsl:choose>
      
      <!-- 
        Of all the service matches in $service-matches, extract the biggest 
		  URI from among them.  Then use that biggest URI to select the service.
        -->
      <xsl:variable name="biggest-uri">
         <xsl:call-template name="BiggestMatch">
            <xsl:with-param name="services" select="$service-matches"/>
         </xsl:call-template>
      </xsl:variable>
      <xsl:variable name="service" select="$service-matches[@uri=$biggest-uri]"/>
      
      <!-- Assign DataPower dynamic routing info. -->
      <dp:set-variable name="'var://service/routing-url-sslprofile'"
                      value="$service/sslPP"/>
      <dp:set-variable name="'var://service/routing-url'"
                      value="concat('https://', $service/host, ':', $service/port, $uri)"/>
      
      <!-- Log some results for debugging purposes. -->
      <xsl:message dp:priority="notice" dp:type="{$category}">
         Inbound URI = <xsl:value-of select="$uri"/>
      </xsl:message>      
      <xsl:message dp:priority="info" dp:type="{$category}">
         Service Target = <xsl:value-of select="$service/host"/>:<xsl:value-of select="$service/port"/>
      </xsl:message>
      <xsl:message dp:priority="debug" dp:type="{$category}">
         Route File = <xsl:value-of select="$dpconfig:RouteFile"/>
      </xsl:message>      
      <xsl:message dp:priority="debug" dp:type="{$category}">
         SSL Proxy Profile = <xsl:value-of select="$service/sslPP"/>
      </xsl:message>      
      <xsl:message dp:priority="debug" dp:type="{$category}">
         URI Match Pattern = <xsl:value-of select="$biggest-uri"/>
      </xsl:message>      
      <xsl:message dp:priority="debug" dp:type="{$category}">
         Service Name = <xsl:value-of select="$service/name"/>
      </xsl:message>
   </xsl:template>

   <!--
     Recursively iterate through matches to find most specific URL
     -->
   <xsl:template name="BiggestMatch">
      <xsl:param name="services"/>
      <xsl:param name="index"          select="1"/>
      <xsl:param name="bigName"        select="''"/>
      <xsl:variable name="currentName" select="$services[$index]/@uri"/>
      <xsl:variable name="biggerName">
         <xsl:choose>
            <xsl:when test="string-length($bigName) &gt; string-length($currentName)">
               <xsl:value-of select="$bigName"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:value-of select="$currentName"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      
      <xsl:choose>
         <xsl:when test="$index &lt; count($services)">
            <xsl:call-template name="BiggestMatch">
               <xsl:with-param name="services" select="$services"/>
               <xsl:with-param name="index"    select="$index + 1"/>
               <xsl:with-param name="bigName"  select="$biggerName"/>
            </xsl:call-template>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="$biggerName"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   
</xsl:stylesheet>