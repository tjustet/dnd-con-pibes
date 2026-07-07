<script setup>
import { ref, onMounted, nextTick } from 'vue'

const props = defineProps({
  campaignId: { type: String, required: true },
  pantallaCompleta: { type: Boolean, default: false } // Clave para adaptar el diseño
})

const supabase = useSupabaseClient()

const notas = ref([])
const notaActiva = ref(null)
const editorRef = ref(null)
const tituloInputRef = ref(null) // Para enfocar el título automáticamente
const colorSeleccionado = ref('#facc15')

const hoverPreview = ref({ visible: false, url: '', x: 0, y: 0 })
let timeoutImagen = null

const cargarNotas = async () => {
  const { data } = await supabase
    .from('campana_notas')
    .select('id, titulo, contenido, created_at')
    .eq('campaign_id', props.campaignId)
    .order('created_at', { ascending: false })
  
  if (data) {
    notas.value = data
    if (data.length > 0) abrirNota(data[0])
  }
}

const crearNota = async () => {
  // Ya no hay prompt. Creamos directo.
  const { data, error } = await supabase.from('campana_notas').insert([{
    campaign_id: props.campaignId,
    titulo: 'Nuevo Pergamino',
    contenido: ''
  }]).select().single()

  if (!error) {
    notas.value.unshift(data)
    abrirNota(data)
    
    // Enfocamos el título automáticamente para que el DM pueda renombrarlo al instante
    nextTick(() => {
      if (tituloInputRef.value) {
        tituloInputRef.value.focus()
        tituloInputRef.value.select() // Selecciona el texto para sobreescribirlo rápido
      }
    })
  }
}

const abrirNota = (nota) => {
  notaActiva.value = nota
  if (editorRef.value) {
    editorRef.value.innerHTML = nota.contenido || ''
  }
}

const borrarNota = async (id) => {
  if (confirm("¿Estás seguro de destruir estos registros prohibidos?")) {
    await supabase.from('campana_notas').delete().eq('id', id)
    notas.value = notas.value.filter(n => n.id !== id)
    if (notaActiva.value?.id === id) {
      notaActiva.value = null
      if (editorRef.value) editorRef.value.innerHTML = ''
    }
  }
}

let saveTimer = null
const procesarInputEditor = () => {
  if (!notaActiva.value) return
  if (editorRef.value) {
    notaActiva.value.contenido = editorRef.value.innerHTML
  }
  
  clearTimeout(saveTimer)
  saveTimer = setTimeout(async () => {
    await supabase.from('campana_notas')
      .update({ titulo: notaActiva.value.titulo, contenido: notaActiva.value.contenido })
      .eq('id', notaActiva.value.id)
  }, 1000)
}

const aplicarNegrita = () => document.execCommand('bold', false, null)
const aplicarColor = (event) => document.execCommand('foreColor', false, event.target.value)

const insertarImagenMagica = () => {
  const seleccion = window.getSelection()
  if (!seleccion.rangeCount || seleccion.toString().trim() === '') {
    return alert("Primero selecciona un texto con el mouse para convertirlo en una imagen mágica.")
  }
  
  const url = prompt("Pega la URL de la imagen aquí:")
  if (!url) return

  const range = seleccion.getRangeAt(0)
  const spanMagico = document.createElement('span')
  
  spanMagico.className = 'link-magico-img'
  spanMagico.dataset.imgUrl = url
  spanMagico.textContent = seleccion.toString()
  
  range.deleteContents()
  range.insertNode(spanMagico)
  
  procesarInputEditor() 
}

const manejarEventosEditor = (e) => {
  const target = e.target.closest('.link-magico-img')
  
  if (e.type === 'mouseover' && target) {
    timeoutImagen = setTimeout(() => {
      hoverPreview.value = {
        visible: true,
        url: target.dataset.imgUrl,
        x: e.clientX + 15,
        y: e.clientY + 15
      }
    }, 600)
  }
  
  if (e.type === 'mousemove' && target && hoverPreview.value.visible) {
    hoverPreview.value.x = e.clientX + 15
    hoverPreview.value.y = e.clientY + 15
  }

  if (e.type === 'mouseout') {
    clearTimeout(timeoutImagen)
    hoverPreview.value.visible = false
  }

  if (e.type === 'click' && target) {
    navigator.clipboard.writeText(target.dataset.imgUrl)
    alert("🔗 ¡Enlace de imagen copiado al portapapeles!")
  }
}

onMounted(() => { cargarNotas() })
</script>

<template>
  <div :class="['layout-notas-base', props.pantallaCompleta ? 'modo-full' : 'modo-incrustado']">
    
    <div v-if="hoverPreview.visible" class="visor-flotante" :style="{ top: hoverPreview.y + 'px', left: hoverPreview.x + 'px' }">
      <img :src="hoverPreview.url" />
    </div>

    <div class="sidebar-notas">
      <div class="header-sidebar flex-between">
        <h3 class="font-cinzel t-dorado m-0">Grimorio</h3>
        <button @click="crearNota" class="btn-dorado mini">+ Nueva</button>
      </div>
      
      <div class="lista-notas-scroll mt-1">
        <div v-if="notas.length === 0" class="txt-gris txt-chico text-center p-1">El grimorio está vacío.</div>
        <div 
          v-for="n in notas" :key="n.id" 
          :class="['tarjeta-nota-mini', notaActiva?.id === n.id ? 'activa' : '']"
          @click="abrirNota(n)"
        >
          <div class="flex-1 overflow-hidden text-ellipsis">{{ n.titulo }}</div>
          <button @click.stop="borrarNota(n.id)" class="btn-borrar-nota">✖</button>
        </div>
      </div>
    </div>

    <div class="area-editor" v-if="notaActiva">
      <div class="toolbar-editor">
        <input type="text" ref="tituloInputRef" v-model="notaActiva.titulo" @input="procesarInputEditor" class="input-titulo-nota" placeholder="Título de la nota..." />
        
        <div class="herramientas-texto">
          <button @click="aplicarNegrita" class="btn-tool" title="Negrita"><b>B</b></button>
          <div class="tool-color" title="Color de Texto">
            <span class="icono-color">🎨</span>
            <input type="color" v-model="colorSeleccionado" @change="aplicarColor" class="input-color-picker" />
          </div>
          <div class="separador"></div>
          <button @click="insertarImagenMagica" class="btn-tool img-magica" title="Selecciona un texto primero">✨ Texto -> Imagen</button>
        </div>
      </div>

      <div class="contenedor-hoja">
        <div 
          ref="editorRef"
          class="hoja-papel-editor"
          contenteditable="true"
          @input="procesarInputEditor"
          @mouseover="manejarEventosEditor"
          @mouseout="manejarEventosEditor"
          @mousemove="manejarEventosEditor"
          @click="manejarEventosEditor"
          placeholder="Escribe tus secretos de campaña aquí..."
        ></div>
      </div>
    </div>
    
    <div v-else class="area-vacia flex-center w-full">
      <h3 class="txt-gris font-cinzel opacity-50">Selecciona o crea un pergamino</h3>
    </div>
  </div>
</template>

<style scoped>
/* ESTILOS BASE COMPARTIDOS */
.layout-notas-base { display: flex; background: #050505; color: #e2e8f0; font-family: 'Inter', sans-serif; overflow: hidden; }

/* MODO INCRUSTADO (Para el dm.vue) */
.modo-incrustado {
  height: 650px; /* Un poco más alto para mejor lectura */
  border: 2px solid #1e293b; 
  border-radius: 8px; 
  margin-top: 20px; 
  box-shadow: 0 10px 30px rgba(0,0,0,0.5);
}

/* MODO PANTALLA COMPLETA (Para la página separada /notas) */
.modo-full {
  height: 100vh;
  width: 100vw;
  border: none;
  border-radius: 0;
  margin: 0;
}

.flex-between { display: flex; justify-content: space-between; align-items: center; }
.flex-1 { flex: 1; }
.text-ellipsis { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.flex-center { display: flex; justify-content: center; align-items: center; }
.w-full { width: 100%; }
.mt-1 { margin-top: 10px; }
.p-1 { padding: 10px; }
.txt-gris { color: #94a3b8; }
.txt-chico { font-size: 0.8rem; }
.font-cinzel { font-family: 'Cinzel', serif; }
.t-dorado { color: #facc15; }
.m-0 { margin: 0; }
.opacity-50 { opacity: 0.5; }

.btn-dorado { background: #b45309; border: 1px solid #f59e0b; color: white; padding: 8px 16px; font-weight: bold; border-radius: 6px; cursor: pointer; transition: 0.2s; }
.btn-dorado.mini { padding: 4px 8px; font-size: 0.75rem; }

.sidebar-notas { width: 250px; background: #0a0a0c; border-right: 1px solid #1e293b; display: flex; flex-direction: column; padding: 15px; flex-shrink: 0; }
.header-sidebar { border-bottom: 1px solid #1e293b; padding-bottom: 10px; }
.lista-notas-scroll { flex: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 8px; }
.tarjeta-nota-mini { display: flex; align-items: center; justify-content: space-between; padding: 10px; background: #111; border: 1px solid #27272a; border-radius: 6px; cursor: pointer; font-size: 0.85rem; transition: 0.2s; }
.tarjeta-nota-mini:hover { background: #18181b; }
.tarjeta-nota-mini.activa { border-color: #b45309; background: rgba(180, 83, 9, 0.1); color: #facc15; font-weight: bold; }
.btn-borrar-nota { background: transparent; border: none; color: #ef4444; font-size: 0.8rem; cursor: pointer; opacity: 0; transition: 0.2s; }
.tarjeta-nota-mini:hover .btn-borrar-nota { opacity: 1; }

/* FIX PARA EL SCROLL INTERNO */
.area-editor { 
  flex: 1; 
  display: flex; 
  flex-direction: column; 
  background: #070709; 
  overflow: hidden; 
  min-height: 0; /* Clave para que Flexbox no se expanda infinitamente */
}

.toolbar-editor { background: #0a0a0c; border-bottom: 1px solid #1e293b; padding: 8px 15px; display: flex; align-items: center; justify-content: space-between; flex-shrink: 0; }
.input-titulo-nota { background: transparent; border: none; color: #facc15; font-family: 'Cinzel', serif; font-size: 1.2rem; font-weight: bold; outline: none; flex: 1; }
.input-titulo-nota::placeholder { color: #475569; }

.herramientas-texto { display: flex; align-items: center; gap: 10px; background: #111; padding: 4px 8px; border-radius: 6px; border: 1px solid #27272a; }
.btn-tool { background: #1e293b; border: 1px solid #334155; color: white; border-radius: 4px; padding: 4px 10px; cursor: pointer; font-size: 0.85rem; transition: 0.2s; }
.btn-tool:hover { background: #3b82f6; border-color: #60a5fa; }
.btn-tool.img-magica { background: rgba(180, 83, 9, 0.2); border-color: #b45309; color: #facc15; font-weight: bold; }
.btn-tool.img-magica:hover { background: #b45309; color: white; }
.separador { width: 1px; height: 16px; background: #334155; }
.tool-color { position: relative; display: flex; align-items: center; justify-content: center; background: #1e293b; border: 1px solid #334155; border-radius: 4px; padding: 4px; cursor: pointer; width: 28px; height: 28px; box-sizing: border-box; }
.icono-color { font-size: 0.85rem; pointer-events: none; z-index: 2; }
.input-color-picker { position: absolute; opacity: 0; width: 100%; height: 100%; cursor: pointer; z-index: 3; }

/* CONTENEDOR DE LA HOJA: AQUÍ PASA EL SCROLL REAL */
.contenedor-hoja { 
  flex: 1; 
  overflow-y: auto; 
  padding: 15px; 
  display: flex; 
  justify-content: center; 
  min-height: 0; /* Clave de Flexbox */
}

.hoja-papel-editor { 
  width: 100%; 
  max-width: 800px; 
  height: max-content; /* Crece sólo lo que necesita */
  min-height: 100%; /* Pero siempre ocupa al menos la pantalla */
  background: #0a0a0c; 
  border: 1px dashed #1e293b; 
  padding: 25px; 
  font-size: 1rem; 
  line-height: 1.6; 
  outline: none; 
  border-radius: 8px; 
  box-shadow: inset 0 0 20px rgba(0,0,0,0.5); 
}

.hoja-papel-editor:focus { border-color: #334155; }

:deep(.link-magico-img) { color: #60a5fa; text-decoration: underline; text-decoration-style: dashed; cursor: pointer; font-weight: bold; transition: 0.2s; }
:deep(.link-magico-img:hover) { color: #facc15; text-shadow: 0 0 8px rgba(250, 204, 21, 0.5); }
.visor-flotante { position: fixed; z-index: 9999; pointer-events: none; border: 2px solid #b45309; border-radius: 8px; box-shadow: 0 10px 25px rgba(0,0,0,0.9); background: #000; overflow: hidden; max-width: 400px; max-height: 400px; }
.visor-flotante img { max-width: 100%; max-height: 100%; object-fit: contain; display: block; }
</style>