# Ejemplos de una instalación sin internet usando kcli

En este directorio tenemos diferentes archivos que debemos entender cómo leer
según su extensión:

* **Archivos `.yml`:** planes de kcli
* **Archivos `.ign`:** ignition files. Se generan con el `Makefile` provisto,
  usando make. Necesita el comando `butane` que en realidad se corre usando
  podman. En todo caso cambiar el alias en el Makefile
* **Archivos `.bu`** butane files. Son YAML que se usan para generar lso
  ignition files de forma más simple usando el comando butane. El `Makefile`
  simplifica su generación.

## Crear los archivos Ignition

Con el `Makefile` provisto, se crearán los ignition files a partir de los butane
provistos. Dado que realizaremos una instalación totalmente desatendida de
internet, lo que haremos es:

* Crear una registry en la misma PC donde se corre la POC. Todas las pruebas
  aquí provistas no requieren docker porque utilizarán [podman](https://podman.io/).
* El propio Makefile creará:
  * Una registry OCI que correrá en nuestra PC puerto 443 usando SSL
  * Los certificados necesarios para servir las imágenes de forma segura con una
    PKI basada en una CA autofirmada y un certificado para la registry.
  * Se aprovisionarán los butane configurando las vms del cluster k3s usando la
    CA creada en el punto anterior. Además, se configurará en cada nodo k3s un
    mirror registry que permitirá al cluster funcionar transparentemente usando
    la registry configurada oportunamente.

Por ende, se deberá correr el comando **`make`** que provee targets para
diferentes objetivos. Vale la pena entonces mencionarlos aquí:

* **`all`**: prepara el nodo master y certificados para la registry. Es decir,
  genera los ignition files y sus requerimientos, esto es algunos archivos de
  configuración para el sistema, y que se provee como template en la carpeta
  `ignition-assets/`. Requiere se envíe la variable de ambiente:
  * **`REGISTRY_IP`**: sería la misma PC donde se corre `make`. Puede usar el
    comando `hostaname -I` para obtenerla rápidamente.
* **`load-local-registry`**: inicia la registry usando `sudo podman` para poder
  abrir el puerto 443. Una vez iniciada la registry, se cargan las imágenes
  necesarias para que se configure fedora core os usando una imagen OCI y aquellas
  imágenes usadas por k3s para funcionar.
* **`agent`**: prepara los nodos de k3s si es que se necesita un ambiete en HA.
  Para ello, necesita generar los ignition files del agente que dependen de la
  existencia del nodo master de k3s. Requiere las variables de ambiente:
  * **`K3S_API_SERVER_IP`**: la ip del nodo master de k3s ya aprovisionado.
    Puede usar el comando: `kcli show vm k3s-airgapped-server -f ip | cut -d: -f2 | tr -d ' ')`
  * **`K3S_API_SERVER_TOKEN`**: el token que se obtiene al igual que la ip
    accediendo por ssh. Puede usarse el comando: `kcli ssh k3s-airgapped-server sudo cat /var/lib/rancher/k3s/server/token`
  * **`REGISTRY_IP`**: si ya se generó el template para el server, seguramente
    no sea necesario enviarla. Es la misma instrucción explicada en `all`.
* **`clean-agent`**: elimina todo lo generado para los nodos HA
* **`clean`**: elimina todo lo generado, incluso la registry.

## Inicializando la registry


Como se mencionó, primero creamos la registry le cargamos las imágenes
necesarias:

```bash
REGISTRY_IP=$(hostname -I | cut -f 1 -d ' ') make load-local-registry
```
> Es importante tener podman instaldo y libre el puerto 443.

Este comando inciará con `sudo podman` (por ello pedirá contraseña para correr
podman) una registry OCI en el puerto 443. Previo a hacerlo, creará certificados
firmados por una CA para:
* La IP enviada en la variable `$REGISTRY_IP`
* Un hostname que se genera con nip.io, será `registry.$REGISTRY_IP.nip.io`

Una vez que inició el servicio de la registry, se procede a descargar para el
release de k3s ya instalado en la [imágen provista por este
repositorio](../layered-image/Containerfile), un tar con las imágenes usadas en
la instalación _airgapped de k3s_. De éste tar se descromprime el _manifiesto_ y
copia cada imágen en el tar usando [skopeo](https://github.com/containers/skopeo)
a través de podman.

Luego de cargar las varias imágenes en nuestra registry local, copiamos usando
también skopeo desde la registry de github a nuestra registry local, las
imágenes necesarias para configurar fedora core os usando layered images vía,
rpm-ostree. Esta vez, será desde la registry local.

## Instalando el servidor

Usaremos kcli para simplificar la incialización de las virtuales en kvm usando
ignition files.

> Un detalle importante para verificar la prueba realmente funciona sin internet,
> es filtrar el tráfico para los nodos aprovisionados. Es justamente por esta
> razón, que si se inspecciona el yml de kcli, puede verse una mac address fija
> que puede usarse para garantizar la nos salida a internet de estas máquinas
> configurando un firewall. En el ejemplo, se utiliza una red llamada local que es
> la misma red donde correremos la registry, para que la misma sea accesible, pero
> no a internet.

Se provee el archivo llamado `k3s-airgapped-server.yml` que define lo que sería
la cirtual del nodo server. Esta vm tomará la configuración del archivo `.ign`
con igual nombre.

```bash
REGISTRY_IP=$(hostname -I | cut -f 1 -d ' ') make
kcli create plan k3s-airgapped -f k3s-airgapped-server.yml
```
> Creará la vm. Notar que el comando `make` al no especificar target invocará
> `all` que es el primero de la lista.

Para destruirla:

```bash
kcli delete vm k3s-airgapped-server
```

### Nodos agentes de k3s

Los agentes, son similares al server. Solamente difieren en que el servicio que
inician corresponde a un nodo y no un server. Sin embargo, para que se unan al
cluster, necesitamos setear en el agente una serie de datos que se obtienen del
**server**:

* La URL del servidor
* El token para que un nodo se una al cluster

Esto se menciono anteriormente para el target del `Makefile` llamdo `agent`.
Podemos entonces en un comando correr, una vez iniciado el nodo master, el
siguiente comando:

```bash
K3S_API_SERVER_IP=$(kcli show vm k3s-airgapped-server -f ip | \
  cut -d: -f2 | tr -d ' ') \
  K3S_API_SERVER_TOKEN=$(kcli ssh k3s-airgapped-server sudo \
  cat /var/lib/rancher/k3s/server/token) make agent
```

Luego podemos iniciar el/los nuevos nodos agentes usando:

```bash
kcli create plan k3s-airgapped -f k3s-airgapped-nodes.yml
```

> El archivo provisto creará dos nodos, cada uno también con una mac fijada de
> forma tal de poder filtrar desde el firewall.

Para destruir cada nodo:

```bash
kcli delete vm k3s-airgapped-node-1
kcli delete vm k3s-airgapped-node-2
```

### Destruir todo

Es posible eliminar todo usando:

```bash
kcli delete plan k3s-airgapped
```

Luego, eliminamos configuraciones y bajamos la registry usando:

```bash
make clean
```
