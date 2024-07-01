TAPAS-xq
========

TAPAS-xq is an EXPath application to manage [TEI](https://tei-c.org/)-encoded resources in an XML database. TAPAS-xq provides an API for the [Ruby on Rails component of TAPAS](https://github.com/NEU-DSG/tapas_rails) to accomplish tasks that are easier to do in an XML-native environment. Among these tasks:

- Test that files are wellformed XML in the TEI namespace.
- Store and index TEI files.
- Generate MODS metadata for TEI files, using the `<teiHeader>` and information provided by the uploader.
- Transform TEI files into XHTML through TAPAS view packages.

TAPAS-xq also provides scripts for maintaining and updating the TAPAS view packages with the help of the GitHub and TAPAS Rails APIs.


## Table of Contents

- [Context for the TAPAS ecosystem](#context-for-the-tapas-ecosystem)
  - [View packages](#view-packages)
- [Using TAPAS-xq](#using-tapas-xq)
- [The code of TAPAS-xq](#the-code-of-tapas-xq)
- [Setup and installation](#setup-and-installation)
  - [Setting up BaseX](#setting-up-basex)
  - [Deploying TAPAS-xq](#deploying-tapas-xq)
- [Hungry for more TAPAS?](#hungry-for-more-tapas)


## Context for the TAPAS ecosystem

TAPAS-xq manages the XML database component of the [TAPAS website](https://tapasproject.org/). TAPAS-xq stores and indexes the TEI files provided by Rails. We have plans to eventually implement XML-aware search using this database, but at the moment, TAPAS-xq is mainly used to transform users' TEI into MODS metadata records, and into HTML for display in the TAPAS reading interface.

In order to respond to the needs of the Rails application, TAPAS-xq has an [API](API.md) and a single user, "tapas". In order to store documents and request transformations, the Rails app sends HTTP requests to the TAPAS-xq endpoints, along with credentials for the "tapas" user.


### View packages

A "[view package](https://github.com/NEU-DSG/tapas-view-packages)" is a collection of code used to generate a publication from TEI data. A TAPAS view package contains:

- a program to turn TEI into some other format (usually HTML);
- any CSS, Javascript, or images needed to correctly display the publication; and
- one configuration file, defining how to run the transformation and how to display its output.

The view package system was created so that TAPAS's Rails and BaseX components could each maintain a registry of the "views" available in TAPAS. This would make it easier to add new view packages, delete old ones, or simply make updates to existing packages. Because each component must maintain its own copy of the view packages, their registries must include information about the version of the packages. We use the git commit hash and timestamp for this purpose.

When installed, TAPAS-xq clones its own local copy of the [`tapas-view-packages` repository](https://github.com/NEU-DSG/tapas-view-packages) into its main directory. TAPAS-xq has API endpoints for [viewing the view package registry](API.md#list-registered-view-packages), and for updating its repository using the latest commits from GitHub.


## Using TAPAS-xq

To interact with TAPAS-xq, you must make [RESTful HTTP requests](https://restfulapi.net/) through the API. For testing purposes, you may need to use the `curl` command line tool to make requests.

**Note:** Any request for storage or deletion *must* include valid credentials for a BaseX user with "write" permissions for the TAPAS databases. TAPAS-xq sets up the "tapas" user for that purpose.

For more specific information on the API endpoints, please refer to the [API documentation on GitHub](API.md), or make a request to the `/tapas-xq/api` endpoint.

For example, say you wanted to test uploading a TEI file to the database. The API documentation lists an endpoint to ["Store core file and supplementals"](API.md#store-core-file-and-supplementals). You could compile the required information and send a `curl` request that looks like this:

```shell
curl -F file=@resources/testdocs/sampleTEI.xml \
     -F collections=coll01,coll02 \
     -F is-public=true \
     -F title="Sample TEI File" \
     -F contributors="Ash Clark" \
     -u tapas -v \
  http://localhost:8080/tapas-xq/project01/testdoc
```

The command above sends the sample TEI file and associated metadata to a local instance of TAPAS-xq.

When it receives the above request, TAPAS-xq stores the TEI file in the `tapas-data` database as `/tapas-data/project01/testdoc/testdoc.xml`. TAPAS-xq also creates a small file, the "TFE", which contains information about where "testdoc" is placed in the "project01" project (the collections "coll01" and "coll02"), and who has access to it (everyone; the file is public). TAPAS-xq will also create a MODS metadata record, save it into the database, and respond to the user request with a copy of the MODS file.

Note that the original filename is not preserved; the document ID "testdoc" becomes the name of the TEI file as TAPAS-xq knows it.


## The code of TAPAS-xq

TAPAS-xq is comprised of several XQuery modules, or libraries. These can be found in the ["modules" folder](./modules/).

The primary files are these:

- **[`tapas-api.xql`](modules/tapas-api.xql)**, which defines the API endpoints using [RESTXQ](https://docs.basex.org/wiki/RESTXQ);
- **[`general-functions.xql`](modules/general-functions.xql)**, which houses general functions used in other modules; and
- **[`view-packages.xql`](modules/view-packages.xql)**, which houses functions for getting, using, and interpreting the view package system.

The ["resources" folder](./resources/) contains other useful files, such as

- TEI documents for use in testing TAPAS-xq;
- a Schematron file to determine if a file should be considered TEI by TAPAS-xq;
- XSLT for generating the API documentation from the [xqDoc comments](http://xqdoc.org/xqdoc_comments_doc.html) in `tapas-api.xql`; and
- XSLT for turning TEI into MODS metadata.


## Setup and installation

For local development work, you may wish to use the [Docker instructions](docker/README.md). The Docker environment handles all the configuration below for you, letting you skip right to actually using the TAPAS-xq API through BaseX.


### Setting up BaseX

TAPAS-xq is designed to run in [BaseX](https://basex.org/), an open source XML database engine. [Download either the ZIP or WAR package](https://basex.org/download/) of BaseX at major semantic version 10 or 11.

If using the BaseX ZIP, unpack the archive and place the directory wherever you'd like.

If using the BaseX WAR, place the web archive in the `webapps` directory of [Apache Tomcat](https://tomcat.apache.org/). Then, start Tomcat in order to unpack the archive.

To make full use of TAPAS-xq, you will need to configure BaseX further:

- [Set up credentials for the BaseX "admin" account](#set-up-credentials-for-the-basex-admin-account)
- [Enable XSLT 3.0 transformation](#enable-xslt-30)
- [Require authentication through BaseX](#require-authentication)
- [Deploy TAPAS-xq](#deploying-tapas-xq)


#### Set up credentials for the BaseX "admin" account

BaseX no longer sets the password for the "admin" user by default.

Luckily for users of the BaseX ZIP package, setting the password is easy. From the BaseX directory, run `bin/basexhttp -c PASSWORD` to be prompted for a new password. After setting the password, the BaseX server will start up. Shut it down again by pressing the <kbd>Control</kbd> and <kbd>c</kbd> keys.

It's a little harder to set the admin password for the BaseX WAR installation. Here are the steps (with gratitude for [Thanthla's answer on StackOverflow](https://stackoverflow.com/a/76061691)):

1. Make sure there's a folder called "data" in the BaseX directory. If the folder doesn't exist, create it.
2. Create a new file, `data/users.xml`, containing the XML below. This will set the "admin" password to "admin".
```xml
<users>
  <user name="admin" permission="admin">
    <password algorithm="digest">
      <hash>304bdfb0383c16f070a897fc1eb25cb4</hash>
    </password>
    <password algorithm="salted-sha256">
      <salt>57488523240000</salt>
      <hash>53cc1d7542a03f6e0e11d087f0f82544fa73da95b8f753fe4be68fead71166f3</hash>
    </password>
  </user>
</users>
```
3. Restart Tomcat.
4. You'll be able to reset the admin password in BaseX's Database Administration app.


#### Enable XSLT 3.0

BaseX will allow XSL 3.0 transformations if it finds a [Saxon processor](https://www.saxonica.com) on the classpath.

To set this up, [download the latest Saxon HE package](https://github.com/Saxonica/Saxon-HE/releases) and unpack it. Place the extracted directory into `BASEX/lib/custom` (ZIP installation) or `BASEX/lib` (WAR installation). You'll need to restart BaseX so that it registers the library.

To make sure you've installed Saxon HE correctly, navigate to `BASE-URL/dba/editor` in your browser, and run `xslt:processor()`. You should see the result "Saxon HE", not "Java".


#### Require authentication

The TAPAS-xq app requires authentication for a majority of actionable HTTP request methods, including the `DELETE` method.

By default, [BaseX is configured with a default user](https://docs.basex.org/wiki/Web_Application#Authentication) for requests processed through RESTXQ apps. Unfortunately, if this setting is in place, authentication cannot take place through standard protocols. Instead, one must ask for and receive usernames and passwords in plaintext, through query parameters or special-cased request headers. This is not great for security.

To make use of [standard authentication schemes](https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication#authentication_schemes), BaseX **must** be configured so that there is no default user for the RESTXQ service. 

To do so, find the `web.xml` file inside the BaseX folder. If you downloaded the ZIP package, the file will be located at `webapps/WEB-INF/web.xml`. 

Inside `web.xml`, find the RESTXQ service entry and either comment out the `<init-param>` that sets the `org.basex.user` property, or delete the setting completely. An example is given below.

```xml
  <servlet>
    <servlet-name>RESTXQ</servlet-name>
    <servlet-class>org.basex.http.restxq.RestXqServlet</servlet-class>
    <!--<init-param>
      <param-name>org.basex.user</param-name>
      <param-value>admin</param-value>
    </init-param>-->
    <load-on-startup>1</load-on-startup>
  </servlet>
```

While not strictly necessary, it is also helpful to set some additional [configuration options](https://docs.basex.org/wiki/Options):

```xml
  <!-- By default, index attributes that look like IDs or keys. -->
  <context-param>
    <param-name>org.basex.attrinclude</param-name>
    <param-value>*:id,ID,key</param-value>
  </context-param>
  <!-- By default, index diacritics. -->
  <context-param>
    <param-name>org.basex.diacritics</param-name>
    <param-value>true</param-value>
  </context-param>
  <!-- By default, serialized documents aren't indented. -->
  <context-param>
    <param-name>org.basex.serializer</param-name>
    <param-value>indent=no</param-value>
  </context-param>
  <!-- By default, BaseX will skip over files that it can't parse, rather than 
    returning an error. -->
  <context-param>
    <param-name>org.basex.skipcorrupt</param-name>
    <param-value>true</param-value>
  </context-param>
```

Settings (such as the ones above) can be placed directly beneath the `<description>` tag in `web.xml`.


### Deploying TAPAS-xq

TAPAS-xq can be installed by navigating into the BaseX `webapp` directory and cloning the repository from GitHub:
```shell
git clone https://github.com/NEU-DSG/tapas-xq.git
```

Then, you'll need to run the installation script. If you used the ZIP method of installing BaseX, you can run the script with this command:
```shell
bin/basex webapp/tapas-xq/modules/installation.bxs
```

If you used the Tomcat WAR method of installing BaseX, you'll need to use `curl` to prompt BaseX to run the script, e.g.
```shell
curl -X GET -u admin "http://localhost:8088/BaseX107/rest?run=tapas-xq/modules/installation.bxs"
```

The [TAPAS-xq installation script](modules/installation.bxs) sets up the `tapas-data` and `tapas-view-packages` databases for you. It also sets up the "tapas" user (whose default password is "tapas"). The "tapas" user is the primary user of the TAPAS-xq; it is the account through which the TAPAS Rails service interacts with the TAPAS-xq databases.

**Note:** Earlier versions of TAPAS-xq were installed by generating an [EXPath application "XAR file"](http://expath.org/spec/pkg#concepts). This method is no longer useful for installation, since BaseX doesn't register API endpoints when XQuery modules are installed from XARs. We have retained the [EXPath package descriptor](./expath-pkg.xml), which is still helpful for tracking versions and dependencies.


***

## Hungry for more TAPAS?

[TAPAS website](https://tapasproject.org/)

[TAPAS Rails repository](https://github.com/NEU-DSG/tapas_rails)

[TAPAS View Packages repository](https://github.com/NEU-DSG/tapas-view-packages)

[Public documents, documentation, and meeting notes for TAPAS](https://github.com/NEU-DSG/tapas-docs)
