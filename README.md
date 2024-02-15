# k3s en Fedora Core OS

Este repositorio muestra cómo podemos crear una imagen que será usada como
[ostree native container](https://coreos.github.io/rpm-ostree/container/) para
el despliegue de k3s de forma inmutable.

## Prerequisitos

Si bien este lab podría realizarse con libvirt, directamente con virsh,
proponemos el uso de [kcli](https://kcli.readthedocs.io/en/latest/).

## Ejemplos

Veremos que en la carpeta [`examples/`](./examples) entregamos diferentes
ejemplos de cómo crear máquinas con diferentes configuraciones.

Para probarlos, recomendamos entonces clonar este repositorio y trabajar con
estos directorios modificando los ejemplos según sea necesario.

Dentro del directorio hay más documentación.

## Generación de la capa layered

Como se explica en la documentación propia de coreos mencionada en la
introducción, se construye un contenedor que es la imagen que se mergea con la
raíz de Fedora Core OS.

De esta forma, al construir el [`Containerfile`](layered-image/Containerfile) de
la carpeta [`layered-image/`](./layered-image), podremos luego usarla desde
systemctl para inicializar el sistema.

Este repositorio usará la registry de github para promover su uso desde este
ejemplo usando GH Actions.
