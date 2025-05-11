## 📦 Configuración del Proyecto SSIS

Este proyecto utiliza **parametrización centralizada** mediante archivos `.params` para facilitar el despliegue y la ejecución local en diferentes entornos de desarrollo.

---

### 📁 Archivos relevantes

- `Project.params.example`: Archivo de ejemplo con estructura válida. **Sí se incluye en el repositorio.**
- `Project.params`: Archivo personalizado con valores locales. **NO se sube al repositorio.**

---

### ⚙️ ¿Cómo usarlo?

1. **Copia el archivo de ejemplo:**

```bash
cp Project.params.example Project.params
```

2. **Edita `Project.params` con tus valores locales dentro de VS:**
   - 🔧 Cambia nombres de servidor.
   - 📂 Cambia rutas o nombres de base de datos.
---

> ⚠️ **Importante:**  
> No modifiques `Project.params.example` directamente.  
> Este archivo actúa como plantilla común para todo el equipo.  
> Solo debe actualizarse si cambia la **estructura de los parámetros** que todos deben conocer.
