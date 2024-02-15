# Ejemplos con kcli

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

Simplemente se corre el comando `make` dentro de ésta carpeta. Para que
funcione, se requiere contar con ese comando, así como el usado por él. En este
caso podman, que define un alias para lo que sería butane.

Al correrlo, deberán aparecer los archivos con el mismo nombre que `.bu` pero
con extensión `.ign`. No versionamos los ignition files porque dependen de cada
prueba.

## Crear una vm con kcli

La forma más simple es usando la cli de kcli. Para ello, crearemos un plan con
el nombre de cada prueba.

### Nodo server de k3s

Se provee el archivo llamado `k3s-with-selinux.yml` que define lo que sería la
vm del nodo server. Esta vm tomará la configuración del archivo `.ign` con igual
nombre.

```bash
kcli create plan k3s-with-selinux -f k3s-with-selinux.yml
```

> Creará la vm

Para destruirla:

```bash
kcli delete plan k3s-with-selinux
```

### Nodos agentes de k3s

Los agentes, son similares al server. Solamente difieren en que el servicio que
inician corresponde a un nodo y no un server. Sin embargo, para que se unan al
cluster, necesitamos setear en el agente una serie de datos que se obtienen del
maestro:

* La URL del servidor
* El token para que un nodo se una al cluster

```bash
```

