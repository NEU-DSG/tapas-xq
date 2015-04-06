TAPAS-xq
=======

An EXPath application to manage TAPAS's interests inside eXist-db, including generation of the TEI documents considered canonical within TAPAS (a.k.a. the TAPAS-friendly copy, or TFC).

## Installation
It's assumed you have eXist-db up and running somewhere. If not, see the [eXist Quick Start](http://exist-db.org/exist/apps/doc/quickstart.xml) guide and follow the instructions there.

You'll want to be logged in on the machine where you've installed eXist ([plattr](https://github.com/NEU-DSG/plattr) users should SSH into their Vagrant box).

### Get a copy
Clone down this repository using your git client of choice, then run [Apache Ant](https://ant.apache.org/manual/running.html) from within your local repo. By default, Ant will build a zipped archive from files within the repository, and store the new package in the (git-ignored) `build` directory.

In the terminal:
1. `git clone <URL>`
2. `cd tapas-xq`
3. `ant`

<!-- Once there is a stable release, include instructions for downloading the pre-built package from GitHub! -->

### Deploy the app
#### With eXist's Package Manager
In your browser, navigate to eXist's Dashboard interface. The default URL is http://localhost:8080/exist, but those using plattr should try http://localhost:8848/exist instead.

Log in as the admin user. (Plattr users: the default password is "dsgT@pas".) Click on the icon labeled "Package Manager" and then again on the cylinder in the top-left corner. 

Either drag-and-drop the `.xar` file into the new window, or click on the button to choose the file from a menu.

<!-- There are lots of ways to get packages into eXist: -->
<!-- #### With the Java Admin Client (I think?) -->
<!-- #### By auto-deploying -->
<!-- #### With XQuery -->

## Hungry for more TAPAS?
[TAPAS website](http://www.tapasproject.org/)

[TAPAS public documents, documentation, and meeting notes on GitHub](https://github.com/NEU-DSG/tapas-docs)

[TAPAS Drupal theme on GitHub](https://github.com/NEU-DSG/tapas-themes)

[TAPAS Drupal modules on GitHub](https://github.com/NEU-DSG/tapas-modules)

[TAPAS Hydra Head on GitHub](https://github.com/NEU-DSG/tapas_rails)

[TAPAS virtual machine provisioning on GitHub](https://github.com/NEU-DSG/plattr)