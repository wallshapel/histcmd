# histcmd 🧠⌨️

Historial de comandos **por contexto** para Zsh.

`histcmd` evita que el historial global mezcle comandos de proyectos distintos.  
Cada contexto usa su propio `Histfile`, definido desde un `Histmap.toml`.

---

## ✅ Requisitos

- Linux
- Zsh 5.9 o superior
- Git

Comprueba tu versión de Zsh:

```bash
zsh --version
```

---

## 📦 Instalación

### ⚡ Instalación automática

Clona el proyecto:

```bash
git clone https://github.com/wallshapel/histcmd.git
cd histcmd
```

Ejecuta el instalador:

```bash
./install.sh
```

El instalador se encarga automáticamente de:

- 📁 instalar `histcmd` en `~/.local/share/histcmd`
- 🔗 crear el comando `histcmd` en `~/.local/bin`
- 🛣️ agregar `~/.local/bin` al `PATH` si hace falta
- 🐚 integrar `histcmd` con Zsh mediante `~/.zshrc`
- ♻️ actualizar una instalación existente si vuelves a ejecutarlo
- 🧹 evitar líneas duplicadas en `~/.zshrc`

Después abre una terminal nueva o ejecuta:

```bash
exec zsh
```

Comprueba la instalación:

```bash
histcmd --version
```

### 🔧 Instalación manual

Si prefieres instalarlo manualmente:

```bash
git clone https://github.com/wallshapel/histcmd.git ~/.local/share/histcmd
mkdir -p ~/.local/bin
ln -s ~/.local/share/histcmd/bin/histcmd ~/.local/bin/histcmd
```

Asegúrate de tener `~/.local/bin` en tu `PATH`:

```zsh
export PATH="$HOME/.local/bin:$PATH"
```

Y agrega al final de `~/.zshrc`:

```zsh
source "$HOME/.local/share/histcmd/lib/histcmd.zsh"
```

Después:

```bash
exec zsh
```

---

## 🚀 Crear un workspace

Entra a la raíz de tu proyecto:

```bash
cd mi-proyecto
```

Ejecuta:

```bash
histcmd init
```

Esto crea:

```text
mi-proyecto/
├── Histmap.toml
└── Histfile
```

El `Histfile` de la raíz pertenece **sólo a la raíz**.

---

## 🗺️ Definir contextos

Ejemplo:

```toml
version = 1

[[context]]
path = "."
recursive = false

[[context]]
path = "backend"
recursive = true

[[context]]
path = "frontend"
recursive = true
```

### 🔁 ¿Qué significa `recursive`?

- `recursive = false` → el contexto aplica **sólo al directorio exacto**.
- `recursive = true` → el contexto aplica al directorio y también a sus **subdirectorios**, salvo que exista otro contexto más específico.

Por ejemplo, si `backend` tiene `recursive = true`, entonces `backend/src/` y `backend/tests/` usan `backend/Histfile`.

Esto **no mezcla historiales entre contextos**: sólo define hasta dónde se extiende un contexto.

Y la estructura:

```text
mi-proyecto/
├── Histmap.toml
├── Histfile
├── backend/
│   └── Histfile
├── frontend/
│   └── Histfile
└── docs/
```

Comportamiento:

- 📍 raíz → usa `./Histfile`
- 🔧 `backend/` y sus subdirectorios → usan `backend/Histfile`
- 🎨 `frontend/` y sus subdirectorios → usan `frontend/Histfile`
- 📚 `docs/` → historial vacío
- 🌍 fuera del workspace → vuelve al historial global de Zsh

---

## ⬆️⬇️ ¿Cómo se usa?

Normalmente.

Sólo abre una terminal y usa:

```text
↑
↓
```

`histcmd` selecciona automáticamente el historial correcto según el directorio actual.

También funciona al navegar con:

```bash
cd ..
cd ../../
cd /otra/ruta
```

---

## 🔁 Comandos repetidos

Cada contexto mantiene comandos únicos.

Si ejecutas varias veces:

```bash
git push
```

se conserva una sola entrada y se considera la más reciente.

---

## 🧩 Contextos anidados

Puedes definir contextos dentro de otros contextos:

```text
frontend/
├── Histfile
└── frontend-1/
    └── Histfile
```

Cada `Histfile` permanece completamente aislado.

---

## 📝 Rutas complejas

Los contextos pueden contener espacios, tildes y símbolos:

```toml
[[context]]
path = "1. Recorrido intensivo por C++ y su biblioteca estándar"
recursive = true
```

---

## 🙈 Git

Los `Histfile` son archivos locales y no deberían versionarse.

Puedes ignorarlos globalmente con Git:

```bash
git config --global core.excludesFile ~/.config/git/ignore
mkdir -p ~/.config/git
echo "Histfile" >> ~/.config/git/ignore
```

---

## 🧪 Estado actual

Esta es la **V1**.

La prioridad es mantener el comportamiento simple y predecible:

> Dentro de un workspace, cada terminal pertenece a un único contexto o a ninguno. Nunca se mezclan historiales.

Más adelante podrán añadirse opciones de herencia entre contextos sin cambiar esta base. 🚀
