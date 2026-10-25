# histcmd 🧠⌨️

**Historial de comandos por contexto para Zsh — versión 2.0.0.**

`histcmd` permite trabajar en varios proyectos o partes de un mismo proyecto sin mezclar indiscriminadamente sus historiales. Cada **contexto** tiene su propio archivo `histfile`. Si lo necesitas, puedes **consultar también el historial de otros contextos relacionados**: el padre, todos los ancestros, los hijos directos o todos los descendientes.

La selección del contexto se hace automáticamente al moverte entre directorios. No tienes que ejecutar `histcmd` para consultar el historial: sigues usando **↑**, **↓** y los comandos de historial habituales de Zsh.

> **Importante en la versión 2:** los nombres correctos son `histmap.toml` y `histfile`, **todo en minúsculas**. El archivo de configuración mantiene `version = 1`; ese valor identifica el formato del mapa, **no** la versión de la aplicación.

## Contenido

1. [Requisitos e instalación](#1-requisitos-e-instalación)
2. [Inicio rápido: crear un workspace](#2-inicio-rápido-crear-un-workspace)
3. [Cómo funcionan los contextos](#3-cómo-funcionan-los-contextos)
4. [Padres, ancestros, hijos y descendientes](#4-padres-ancestros-hijos-y-descendientes)
5. [Cómo habilitar cada tipo de herencia](#5-cómo-habilitar-cada-tipo-de-herencia)
6. [Combinar opciones y comprender las prioridades](#6-combinar-opciones-y-comprender-las-prioridades)
7. [Cómo usar y comprobar el historial](#7-cómo-usar-y-comprobar-el-historial)
8. [Creación automática de contextos](#8-creación-automática-de-contextos)
9. [Rutas especiales, Git y límites](#9-rutas-especiales-git-y-límites)
10. [Solución de problemas y referencia rápida](#10-solución-de-problemas-y-referencia-rápida)

---

## 1. Requisitos e instalación

- Linux (por ejemplo, **Arch Linux**).
- **Zsh 5.9** o superior.
- **Git**.

En Arch Linux puedes instalar las dependencias con:

```bash
sudo pacman -S --needed zsh git
zsh --version
```

> El instalador es un script de shell (`install.sh`) y puede ejecutarse desde Bash, pero la **integración interactiva del historial funciona en Zsh**. `histcmd` no instala un sistema equivalente de historial para Bash.

### Instalación automática

```bash
git clone https://github.com/wallshapel/histcmd.git
cd histcmd
./install.sh
```

El instalador:

- instala o actualiza el repositorio en `~/.local/share/histcmd`;
- enlaza el ejecutable en `~/.local/bin/histcmd`;
- añade `~/.local/bin` al `PATH` de Zsh si es necesario;
- añade la carga de `lib/histcmd.zsh` en `~/.zshrc`, sin duplicar esa línea si ya existe.

Abre una terminal nueva de Zsh o ejecuta:

```zsh
exec zsh
histcmd --version
```

La versión correspondiente a este código debe mostrarse como:

```text
histcmd 2.0.0
```

### Instalación manual

```bash
git clone https://github.com/wallshapel/histcmd.git "$HOME/.local/share/histcmd"
mkdir -p "$HOME/.local/bin"
ln -sfn "$HOME/.local/share/histcmd/bin/histcmd" "$HOME/.local/bin/histcmd"
```

Agrega estas líneas a `~/.zshrc` si todavía no están presentes:

```zsh
export PATH="$HOME/.local/bin:$PATH"
source "$HOME/.local/share/histcmd/lib/histcmd.zsh"
```

Reinicia Zsh con `exec zsh` y comprueba con `histcmd --version`.

> Si `~/.local/share/histcmd` ya existe, no vuelvas a clonarlo encima: usa el instalador para actualizar una instalación Git existente o revisa primero su contenido.

---

## 2. Inicio rápido: crear un workspace

Un **workspace** es un árbol de directorios cuya raíz contiene `histmap.toml`. Puedes organizar en él tantos contextos como necesites.

### Paso 1. Crea un proyecto de ejemplo

Desde Zsh:

```zsh
mkdir -p ~/proyectos/demo-histcmd/{backend/api/v1,backend/tools,frontend}
cd ~/proyectos/demo-histcmd
histcmd init
```

`histcmd init` crea, **en el directorio actual**, estos dos archivos:

```text
histmap.toml
histfile
```

El contenido inicial de `histmap.toml` es:

```toml
version = 1

[[context]]
path = "."
recursive = false
```

De momento solo existe el contexto de la raíz.

### Paso 2. Declara los contextos

Abre `histmap.toml` con tu editor y **reemplaza su contenido completo** por este ejemplo:

```toml
version = 1

[[context]]
path = "."
recursive = false

[[context]]
path = "backend"
recursive = true

[[context]]
path = "backend/api"
recursive = true

[[context]]
path = "backend/api/v1"
recursive = true

[[context]]
path = "backend/tools"
recursive = true

[[context]]
path = "frontend"
recursive = true
```

Aquí **todavía no hay herencia entre historiales**. Cada contexto está aislado. Usaremos exactamente este mapa como punto de partida para los ejemplos siguientes.

### Paso 3. Construye los archivos de historial

Estando en la raíz del workspace:

```zsh
histcmd build
```

`build` comprueba el formato de `histmap.toml`, comprueba que existan los directorios declarados y crea los `histfile` faltantes. **No crea los directorios** ni reemplaza los `histfile` que ya existen.

El resultado será una estructura como esta:

```text
demo-histcmd/
├── histmap.toml
├── histfile                    ← raíz
├── backend/
│   ├── histfile                ← backend
│   ├── api/
│   │   ├── histfile            ← backend/api
│   │   └── v1/
│   │       └── histfile        ← backend/api/v1
│   └── tools/
│       └── histfile            ← backend/tools
└── frontend/
    └── histfile                ← frontend
```

Puedes comprobar los archivos creados:

```zsh
find . -name histfile -type f -print
```

**No necesitas ejecutar `histcmd build` cada vez que haces `cd`**. Se utiliza principalmente después de crear o modificar el mapa, para validarlo y preparar los historiales de los contextos declarados.

---

## 3. Cómo funcionan los contextos

Un contexto es una entrada `[[context]]` de `histmap.toml` asociada a un directorio. La raíz se representa mediante `path = "."`.

### `recursive`: aplicar un contexto a sus subdirectorios

```toml
[[context]]
path = "backend"
recursive = true
```

- En `backend/` se usa `backend/histfile`.
- En `backend/src/`, si no tiene un contexto más específico, **también** se usa `backend/histfile`.
- En `backend/api/`, **si está declarado como contexto propio**, se usa `backend/api/histfile` y no el de `backend`.

Si cambias la opción a:

```toml
recursive = false
```

el contexto solo se aplica a su **directorio exacto**. En un subdirectorio sin otro contexto aplicable, `histcmd` puede **crear automáticamente uno nuevo** (consulta la sección 8).

**Regla de selección:** cuando varios contextos pueden aplicar a la ruta actual, gana el **más específico** (el de ruta más profunda que aplique).

### `recursive` no significa heredar historiales

Estas son dos preguntas distintas:

- **¿Qué contexto está activo aquí?** Lo determinan `path` y `recursive`.
- **¿Qué otros historiales puedo consultar desde ese contexto?** Lo determinan `include-parent`, `include-ancestors`, `include-children` e `include-descendants`.

Por ejemplo, `recursive = true` en `backend` **no** hace que `backend/api` vea automáticamente el historial del padre si `backend/api` es un contexto independiente.

---

## 4. Padres, ancestros, hijos y descendientes

Usaremos este mismo árbol de **contextos declarados**:

```text
. (raíz)
├── backend
│   ├── api
│   │   └── v1
│   └── tools
└── frontend
```

Desde el contexto `backend/api`:

| Relación | Contextos correspondientes |
| --- | --- |
| **Padre** | `backend` |
| **Ancestros** | `.` y `backend` |
| **Hijos directos** | `backend/api/v1` |
| **Descendientes** | `backend/api/v1` |

Desde el contexto `backend`:

| Relación | Contextos correspondientes |
| --- | --- |
| **Padre** | `.` |
| **Ancestros** | `.` |
| **Hijos directos** | `backend/api` y `backend/tools` |
| **Descendientes** | `backend/api`, `backend/api/v1` y `backend/tools` |

La diferencia se vuelve evidente en niveles más profundos: `backend/api/v1` es **descendiente** de `backend`, pero **no es hijo directo** de `backend` porque entre ambos está el contexto `backend/api`.

> Estas relaciones se calculan **entre contextos registrados en `histmap.toml`**, no entre todas las carpetas físicas. Si existe `backend/api/v1` pero `backend/api` **no** está declarado como contexto, `backend/api/v1` puede ser un hijo directo del contexto `backend` a efectos de `histcmd`.

### Las cuatro opciones

| Opción | Qué hace al activarla con `true` |
| --- | --- |
| `include-parent` | Añade el historial del **padre inmediato** del contexto activo. |
| `include-ancestors` | Añade los historiales de **todos los ancestros** declarados. |
| `include-children` | Añade los historiales de los **hijos directos** declarados. |
| `include-descendants` | Añade los historiales de **todos los descendientes** declarados. |

Las cuatro opciones son **optativas**. Si no aparecen en un contexto, se consideran desactivadas (`false`). Se configuran **en el contexto desde el cual quieres consultar otros historiales**, no en los contextos que actúan como fuentes.

---

## 5. Cómo habilitar cada tipo de herencia

Estos ejemplos son **alternativas independientes** sobre el mapa creado en la sección 2. Para probar cada uno, modifica **solamente el bloque indicado** de `histmap.toml`. Si vienes de otra prueba, elimina o pon en `false` las opciones activadas anteriormente.

Después de **cada edición**, desde la raíz del workspace ejecuta:

```zsh
histcmd build
exec zsh
```

Reiniciar Zsh permite recargar el contexto con seguridad: modificar un mapa mientras ya hay un historial combinado activo no siempre actualiza inmediatamente todas las fuentes cargadas. Luego entra al directorio indicado en el ejemplo y usa **↑** o `fc -l -20` para consultar los comandos disponibles.

### 5.1. `include-parent`: consultar solo al padre

**Objetivo:** desde `backend/api/v1` queremos consultar también los comandos de `backend/api`, **pero no** los de `backend` ni los de la raíz.

Busca el bloque de `backend/api/v1` y déjalo así:

```toml
[[context]]
path = "backend/api/v1"
recursive = true
include-parent = true
```

Después de validar y reiniciar Zsh:

```zsh
cd ~/proyectos/demo-histcmd/backend/api/v1
fc -l -20
```

**Historiales consultables:**

```text
backend/api/v1/histfile    ← historial propio
backend/api/histfile       ← padre inmediato
```

**No incluye:** `backend/histfile`, `histfile` de la raíz, `backend/tools/histfile` ni `frontend/histfile`.

**Uso típico:** trabajar en una subversión de una API y reutilizar comandos del módulo API, sin importar los del resto del proyecto.

### 5.2. `include-ancestors`: consultar todos los ancestros

**Objetivo:** desde `backend/api/v1` queremos consultar también el historial de `backend/api`, `backend` y la raíz.

Cambia **ese mismo bloque** por:

```toml
[[context]]
path = "backend/api/v1"
recursive = true
include-ancestors = true
```

Después de validar y reiniciar Zsh:

```zsh
cd ~/proyectos/demo-histcmd/backend/api/v1
fc -l -20
```

**Historiales consultables:**

```text
backend/api/v1/histfile    ← historial propio
backend/api/histfile       ← ancestro
backend/histfile           ← ancestro
histfile                   ← ancestro raíz
```

**No incluye:** `backend/tools/histfile` ni `frontend/histfile` porque no son ancestros de `backend/api/v1`.

**Uso típico:** en una carpeta muy específica, reutilizar tanto los comandos del módulo como los comandos generales de todo el proyecto.

### 5.3. `include-children`: consultar únicamente los hijos directos

**Objetivo:** desde `backend` queremos consultar los comandos de `backend/api` y `backend/tools`, **sin incluir** los de `backend/api/v1`.

Busca el bloque de `backend` y configúralo así:

```toml
[[context]]
path = "backend"
recursive = true
include-children = true
```

Después de validar y reiniciar Zsh:

```zsh
cd ~/proyectos/demo-histcmd/backend
fc -l -20
```

**Historiales consultables:**

```text
backend/histfile           ← historial propio
backend/api/histfile       ← hijo directo
backend/tools/histfile     ← hijo directo
```

**No incluye:** `backend/api/v1/histfile`, el historial de la raíz ni el de `frontend`.

**Uso típico:** trabajar desde un módulo principal y recuperar comandos de sus submódulos directos, sin llegar a versiones o ramas más profundas.

### 5.4. `include-descendants`: consultar todos los niveles inferiores

**Objetivo:** desde `backend` queremos consultar también lo ejecutado en `backend/api`, `backend/api/v1` y `backend/tools`.

Cambia el bloque de `backend` por:

```toml
[[context]]
path = "backend"
recursive = true
include-descendants = true
```

Después de validar y reiniciar Zsh:

```zsh
cd ~/proyectos/demo-histcmd/backend
fc -l -20
```

**Historiales consultables:**

```text
backend/histfile           ← historial propio
backend/api/histfile       ← descendiente
backend/api/v1/histfile    ← descendiente
backend/tools/histfile     ← descendiente
```

**No incluye:** el historial de la raíz ni el de `frontend`.

**Uso típico:** trabajar desde la raíz de un módulo y tener disponibles los comandos de todos los contextos que contiene, sin importar su profundidad.

---

## 6. Combinar opciones y comprender las prioridades

Puedes combinar una opción de la familia **ascendente** con otra de la familia **descendente**.

### Ejemplo completo: ancestros + descendientes

Desde `backend/api` queremos ver:

- su propio historial;
- el de sus ancestros (`backend` y la raíz);
- el de sus descendientes (`backend/api/v1`).

Configura este bloque:

```toml
[[context]]
path = "backend/api"
recursive = true
include-ancestors = true
include-descendants = true
```

Desde la raíz ejecuta `histcmd build` y `exec zsh`. Después:

```zsh
cd ~/proyectos/demo-histcmd/backend/api
fc -l -20
```

**Historiales incluidos:**

```text
histfile                   ← ancestro raíz
backend/histfile           ← ancestro
backend/api/histfile       ← contexto activo (donde se guardan nuevos comandos)
backend/api/v1/histfile    ← descendiente
```

**No se incluye** `backend/tools/histfile`: es hermano de `backend/api`, no ancestro ni descendiente. Tampoco se incluye `frontend/histfile`.

### ¿Qué pasa si activo opciones de la misma familia?

El código aplica una prioridad clara:

| Opciones activadas en el mismo contexto | Resultado |
| --- | --- |
| Solo `include-parent = true` | Padre inmediato. |
| Solo `include-ancestors = true` | Todos los ancestros (incluido el padre). |
| Ambas (`include-parent` y `include-ancestors`) | **Prevalece `include-ancestors`**; no se duplica el padre. |
| Solo `include-children = true` | Hijos directos. |
| Solo `include-descendants = true` | Todos los descendientes (incluidos los hijos directos). |
| Ambas (`include-children` y `include-descendants`) | **Prevalece `include-descendants`**; no se duplican los hijos. |

Por claridad, es recomendable activar solo **una opción por familia**. En cualquier caso, la selección es **local al contexto activo**: activar `include-parent` en `backend/api/v1` no provoca que `backend/api` empiece a consultar a `v1`.

### La herencia no es transitiva por sí sola

Supongamos que `backend/api` usa `include-parent = true` y `backend/api/v1` también usa `include-parent = true`. Cuando estás en `v1`, ves **`v1` + `api`**, pero **no** `backend` simplemente porque `api` incluya a su propio padre. Para eso, configura `include-ancestors = true` en `v1`.

---

## 7. Cómo usar y comprobar el historial

### Uso cotidiano

Navega normalmente por el proyecto:

```zsh
cd ~/proyectos/demo-histcmd
cd backend
cd api
cd v1
cd ..
cd ~/proyectos/demo-histcmd/frontend
```

Al cambiar de contexto, `histcmd` selecciona el historial correspondiente. Puedes utilizar:

- **↑ / ↓** para recorrer los comandos de la sesión histórica disponible en ese contexto;
- `fc -l -20` para listar comandos recientes;
- `Ctrl + R` para buscar en el historial mediante el comportamiento habitual de Zsh, según tu configuración de teclas.

Fuera de cualquier workspace con `histmap.toml`, se vuelve al historial global de Zsh.

### Prueba práctica con comandos identificables

Para reconocer fácilmente los comandos de cada contexto, ejecuta estas líneas **en una sesión interactiva de Zsh**, una por una:

```zsh
cd ~/proyectos/demo-histcmd
print -r -- MARCA_RAIZ

cd backend
print -r -- MARCA_BACKEND

cd api
print -r -- MARCA_API

cd v1
print -r -- MARCA_V1

cd ~/proyectos/demo-histcmd/backend/tools
print -r -- MARCA_TOOLS

cd ~/proyectos/demo-histcmd/frontend
print -r -- MARCA_FRONTEND
```

Luego, para probar por ejemplo `include-ancestors` en `backend/api/v1`:

1. Activa `include-ancestors = true` en el bloque de `backend/api/v1` del mapa.
2. Desde la raíz ejecuta `histcmd build` y `exec zsh`.
3. Entra en `backend/api/v1` y pulsa **↑** varias veces, o ejecuta `fc -l -30`.
4. Podrás localizar los comandos con `MARCA_V1`, `MARCA_API`, `MARCA_BACKEND` y `MARCA_RAIZ` (si siguen dentro del límite y de la configuración de historial).

Si activas en cambio `include-children = true` en `backend`, podrás recuperar las marcas de `backend/api` y `backend/tools`, **no** la marca exclusiva de `backend/api/v1`.

> **Ojo:** los archivos guardan **comandos**, no su salida. Se conserva, por ejemplo, `print -r -- MARCA_API`, no solo el texto `MARCA_API` que apareció en pantalla.

### ¿Se mezclan físicamente los `histfile`?

**No.** Con opciones `include-*`, `histcmd` construye una **vista temporal combinada** para el contexto activo. Los comandos nuevos ejecutados desde ese contexto se guardan en **su propio `histfile`**, no en los archivos consultados como fuentes.

Ejemplo: con `include-ancestors = true` en `backend/api/v1`, puedes recuperar un comando que ejecutaste en la raíz, pero si lo vuelves a ejecutar desde `v1`, esa nueva ejecución pertenece al historial de `v1`.

### Comandos repetidos

En los contextos gestionados, `histcmd` configura opciones de historial de Zsh para reducir duplicados y conservar las entradas más relevantes. No debes esperar múltiples entradas idénticas cada vez que repites exactamente un comando.

---

## 8. Creación automática de contextos

Una novedad importante respecto a la guía antigua: **un directorio sin contexto aplicable ya no se queda con un historial vacío**. Al entrar en él en Zsh, `histcmd` puede registrarlo automáticamente como contexto nuevo.

Ejemplo: el mapa declara la raíz con `recursive = false`, pero no declara `docs`:

```zsh
cd ~/proyectos/demo-histcmd
mkdir -p docs
cd docs
```

Si ningún contexto recursivo existente cubre esa ruta, `histcmd`:

1. añade al final de `histmap.toml` una nueva entrada;
2. crea `docs/histfile`;
3. activa el nuevo historial.

El bloque añadido es equivalente a:

```toml
[[context]]
path = "docs"
recursive = true
```

Por el contrario, si `backend` tiene `recursive = true` y entras en `backend/src`, **no** se crea otro contexto para `src`: continúa aplicando `backend`.

> Esta creación automática ocurre al navegar en una sesión de Zsh con la integración cargada. **`histcmd build` no registra automáticamente carpetas que no aparecen en el mapa**; solo valida y prepara los contextos que sí están declarados.

---

## 9. Rutas especiales, Git y límites

### Espacios, tildes y nombres largos

Las rutas pueden contener espacios, tildes y otros caracteres habituales:

```toml
[[context]]
path = "1. Recorrido intensivo por C++ y su biblioteca estándar"
recursive = true
include-ancestors = true
```

Crea el directorio primero y ejecuta `histcmd build` desde la raíz. Las rutas de los contextos deben permanecer **dentro del workspace**. Evita comillas dobles (`"`) y saltos de línea dentro del nombre de un contexto: la creación automática no admite esos nombres y el lector del mapa usa un formato restringido.

### Ignorar historiales en Git

Los archivos `histfile` son **datos locales de la terminal**, por lo que normalmente no conviene versionarlos. En el `.gitignore` del proyecto agrega:

```gitignore
histfile
```

Ese patrón ignora los archivos llamados `histfile` tanto en la raíz como en los subdirectorios. **No ignores `histmap.toml`** si quieres compartir con el equipo la estructura de contextos.

También puedes usar un archivo de exclusiones global de Git:

```bash
mkdir -p ~/.config/git
git config --global core.excludesFile "$HOME/.config/git/ignore"
printf '\nhistfile\n' >> ~/.config/git/ignore
```

Si un `histfile` ya estaba versionado, `.gitignore` no lo retira por sí solo del índice de Git.

### Formato de configuración

`histmap.toml` sigue un **subconjunto concreto** de TOML reconocido por la herramienta. Utiliza la sintaxis mostrada en esta guía:

- `version = 1` una vez;
- uno o más bloques `[[context]]`;
- `path = "..."` y `recursive = true|false` en cada bloque;
- opcionalmente `include-parent`, `include-ancestors`, `include-children` e `include-descendants`, con valores literales `true` o `false`;
- comentarios en líneas independientes que comiencen con `#`, y líneas en blanco.

No presupongas que cualquier característica válida de TOML (por ejemplo, comentarios al final de una declaración o claves arbitrarias) será aceptada por `histcmd build`.

---

## 10. Solución de problemas y referencia rápida

**No aparece `histcmd`:** comprueba que `~/.local/bin` esté en tu `PATH`, que el enlace exista y que hayas abierto o reiniciado Zsh. Ejecuta `histcmd --version`.

**Navego por directorios, pero sigue apareciendo el historial global:** comprueba que la línea `source "$HOME/.local/share/histcmd/lib/histcmd.zsh"` esté en `~/.zshrc` y que hayas iniciado una sesión de Zsh. La integración reacciona a los cambios de directorio y antes de mostrar el prompt.

**Cambié una opción `include-*` y no veo los nuevos historiales:** ejecuta `histcmd build` desde la raíz y reinicia con `exec zsh`; así se recrea la selección del historial con las nuevas fuentes. Si el historial ya estaba combinado, permanecer en el mismo contexto puede conservar la selección anterior durante esa sesión.

**`histcmd build` informa que falta un directorio:** créalo primero. `build` no crea carpetas.

**Aparecen historiales inesperados:** revisa qué contexto está realmente activo. Con `recursive = true`, una subcarpeta puede seguir usando el historial de su contexto superior, salvo que hayas definido otro más específico. Revisa también si activaste `include-ancestors` o `include-descendants`.

**Se creó un contexto que no declaré:** probablemente entraste en una ruta que ningún contexto recursivo cubría. Es el comportamiento de creación automática explicado en la sección 8.

### Comandos disponibles

| Comando | Uso |
| --- | --- |
| `histcmd init` | Crea `histmap.toml` y `histfile` en el directorio actual (si no existen). |
| `histcmd build` | Valida el mapa del directorio actual y crea los `histfile` faltantes de sus contextos declarados. |
| `histcmd --version` o `histcmd -v` | Muestra la versión instalada. |
| `histcmd --help` o `histcmd -h` | Muestra la ayuda de la CLI. |
| `fc -l -20` | Lista comandos recientes desde el historial activo de Zsh. |

### Resumen de configuración

```toml
[[context]]
path = "backend/api"
recursive = true
include-parent = false
include-ancestors = true
include-children = false
include-descendants = true
```

Desde `backend/api`:

- `recursive = true`: el contexto aplica también en subcarpetas que no tengan un contexto más específico.
- `include-ancestors = true`: permite consultar los historiales de `backend` y `.`.
- `include-descendants = true`: permite consultar `backend/api/v1` y cualquier otro contexto registrado por debajo.
- Los comandos ejecutados en `backend/api` se siguen guardando **solamente en `backend/api/histfile`**.

**Idea central:** `histcmd` siempre sabe **dónde guardar** los comandos según el contexto activo. Las opciones `include-*` solo amplían **desde dónde puedes consultar** comandos históricos, sin convertir todos los historiales del proyecto en un único archivo.
