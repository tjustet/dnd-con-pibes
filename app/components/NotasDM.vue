<script setup>
import { nextTick, onBeforeUnmount, onMounted, reactive, ref, watch } from 'vue'
import { onBeforeRouteLeave, onBeforeRouteUpdate } from 'vue-router'

const props = defineProps({
  campaignId: { type: String, required: true },
  pantallaCompleta: { type: Boolean, default: false }
})

const supabase = useSupabaseClient()
const columnas = 'id, campaign_id, titulo, contenido, created_at'
const notas = ref([])
const activa = ref(null)
const cargando = ref(true)
const errorCarga = ref(false)
const creando = ref(false)
const tituloInputRef = ref(null)
const editorRef = ref(null)
const color = ref('#facc15')
const mensaje = ref('')
let contexto = 0
let timerMensaje
let rangoEditor = null

function avisar(texto) {
  clearTimeout(timerMensaje)
  mensaje.value = texto
  timerMensaje = setTimeout(() => { mensaje.value = '' }, 3200)
}

function prepararNota(fila) {
  return reactive({
    ...fila, cambios: {}, version: 0, guardada: 0, timer: null,
    peticion: null, error: false, borrando: false
  })
}

async function cargarNotas() {
  const turno = ++contexto
  notas.value = []
  activa.value = null
  creando.value = false
  cargando.value = true
  errorCarga.value = false
  try {
    const { data, error } = await supabase.from('campana_notas')
      .select(columnas).eq('campaign_id', props.campaignId)
      .order('created_at', { ascending: false })
    if (error) throw error
    if (turno !== contexto) return
    notas.value = data.map(prepararNota)
    activa.value = notas.value[0] ?? null
  } catch {
    if (turno === contexto) errorCarga.value = true
  } finally {
    if (turno === contexto) cargando.value = false
  }
}

async function crearNota() {
  if (creando.value || cargando.value || errorCarga.value) return
  const turno = contexto
  creando.value = true
  try {
    const { data, error } = await supabase.from('campana_notas')
      .insert({ campaign_id: props.campaignId, titulo: 'Nuevo Pergamino', contenido: '' })
      .select(columnas).single()
    if (error) throw error
    if (turno !== contexto) return
    const nota = prepararNota(data)
    notas.value.unshift(nota)
    activa.value = nota
    await nextTick()
    if (activa.value !== nota) return
    tituloInputRef.value?.focus()
    tituloInputRef.value?.select()
  } catch {
    if (turno === contexto) avisar('No se pudo crear la nota.')
  } finally {
    if (turno === contexto) creando.value = false
  }
}

// Cada nota conserva su propio plazo y serializa sus escrituras, incluso al cambiar de hoja.
function guardar(nota) {
  clearTimeout(nota.timer)
  if (nota.peticion) return nota.peticion
  if (nota.version === nota.guardada) return Promise.resolve(true)
  nota.error = false
  nota.peticion = (async () => {
    try {
      while (nota.guardada < nota.version) {
        const version = nota.version
        const campos = Object.keys(nota.cambios)
        const cambios = Object.fromEntries(campos.map(campo => [campo, nota[campo]]))
        const { error } = await supabase.from('campana_notas')
          .update(cambios)
          .eq('campaign_id', nota.campaign_id).eq('id', nota.id).select('id').single()
        if (error) throw error
        for (const campo of campos) {
          if (nota.cambios[campo] <= version) delete nota.cambios[campo]
        }
        nota.guardada = version
      }
      return true
    } catch {
      nota.error = true
      return false
    } finally {
      nota.peticion = null
    }
  })()
  return nota.peticion
}

function editar(campo, valor) {
  const nota = activa.value
  if (!nota || nota.borrando || nota[campo] === valor) return
  nota[campo] = valor
  nota.version++
  nota.cambios[campo] = nota.version
  nota.error = false
  clearTimeout(nota.timer)
  nota.timer = setTimeout(() => guardar(nota), 900)
}

function leerHoja() {
  editar('contenido', editorRef.value.innerHTML)
}

async function guardarPendientes() {
  const resultados = await Promise.all(notas.value.map(guardar))
  if (resultados.every(Boolean)) return true
  avisar('Quedan cambios sin guardar. Reintentá antes de salir.')
  return false
}

onBeforeRouteLeave(guardarPendientes)
onBeforeRouteUpdate((to, from) => {
  if (to.params.id !== from.params.id) return guardarPendientes()
})

function protegerBorrador(evento) {
  if (notas.value.some(n => n.version !== n.guardada)) {
    evento.preventDefault()
    evento.returnValue = ''
  }
}

async function borrarNota(nota) {
  if (nota.borrando || !window.confirm(`¿Eliminar «${nota.titulo || 'Sin título'}»?`)) return
  nota.borrando = true
  const turno = contexto
  try {
    // Si el borrado falla, el borrador y su estado de guardado siguen disponibles.
    clearTimeout(nota.timer)
    if (nota.peticion) await nota.peticion
    const { error } = await supabase.from('campana_notas').delete()
      .eq('campaign_id', nota.campaign_id).eq('id', nota.id).select('id').single()
    if (error) throw error
    if (turno !== contexto) return
    notas.value = notas.value.filter(n => n.id !== nota.id)
    if (activa.value === nota) activa.value = notas.value[0] ?? null
  } catch {
    if (turno === contexto) avisar('No se pudo eliminar la nota.')
    if (nota.version !== nota.guardada) void guardar(nota)
  } finally {
    nota.borrando = false
  }
}

function urlImagen(texto) {
  try {
    const url = new URL(texto)
    return ['https:', 'http:'].includes(url.protocol) ? url.href : ''
  } catch {
    return ''
  }
}

// Reconstruye HTML guardado o pegado con el formato admitido por la hoja.
const etiquetas = new Set('p div br b strong i em u s span font ul ol li blockquote h1 h2 h3 h4 pre code sub sup'.split(' '))
const omitir = new Set(['script', 'style', 'iframe', 'object', 'template', 'svg', 'math', 'noscript'])
function htmlDeHoja(html) {
  const fuente = document.createElement('template')
  fuente.innerHTML = html || ''
  const limpio = document.createElement('div')
  function copiar(origen, destino) {
    for (const hijo of origen.childNodes) {
      if (hijo.nodeType === Node.TEXT_NODE) {
        destino.append(hijo.textContent)
        continue
      }
      if (hijo.nodeType !== Node.ELEMENT_NODE || omitir.has(hijo.localName)) continue
      if (!etiquetas.has(hijo.localName)) {
        copiar(hijo, destino)
        continue
      }
      const nodo = document.createElement(hijo.localName)
      nodo.style.color = hijo.style?.color || hijo.getAttribute('color') || ''
      if (hijo.style) {
        nodo.style.fontWeight = hijo.style.fontWeight
        nodo.style.fontStyle = hijo.style.fontStyle
        nodo.style.textDecorationLine = hijo.style.textDecorationLine
      }
      if (hijo.matches('span.link-magico-img[data-img-url]')) {
        const url = urlImagen(hijo.dataset.imgUrl)
        if (url) {
          nodo.className = 'link-magico-img'
          nodo.dataset.imgUrl = url
        }
      }
      copiar(hijo, nodo)
      destino.append(nodo)
    }
  }
  copiar(fuente.content, limpio)
  return limpio.innerHTML
}

watch(activa, (nota) => {
  ocultarVista()
  rangoEditor = null
  if (editorRef.value && nota) {
    editorRef.value.innerHTML = htmlDeHoja(nota.contenido)
    editorRef.value.parentElement.scrollTop = 0
  }
}, { flush: 'post' })

function pegar(evento) {
  const datos = evento.clipboardData
  if (!datos) return
  const html = datos.getData('text/html')
  if (html) document.execCommand('insertHTML', false, htmlDeHoja(html))
  else document.execCommand('insertText', false, datos.getData('text/plain'))
  leerHoja()
}

function recordarSeleccion() {
  const seleccion = window.getSelection()
  if (!seleccion?.rangeCount) return
  const rango = seleccion.getRangeAt(0)
  if (editorRef.value?.contains(rango.commonAncestorContainer)) rangoEditor = rango.cloneRange()
}

function recuperarSeleccion() {
  const editor = editorRef.value
  if (!editor || activa.value?.borrando) return false
  const rango = rangoEditor?.cloneRange()
  editor.focus({ preventScroll: true })
  if (rango && editor.contains(rango.commonAncestorContainer)) {
    const seleccion = window.getSelection()
    seleccion.removeAllRanges()
    seleccion.addRange(rango)
  }
  return true
}

function formato(comando, valor = null) {
  if (!recuperarSeleccion()) return
  document.execCommand(comando, false, valor)
  recordarSeleccion()
  leerHoja()
}

function insertarImagen() {
  if (!recuperarSeleccion()) return
  const texto = window.getSelection().toString()
  if (!texto.trim()) return avisar('Seleccioná el texto que querés vincular a la imagen.')
  const entrada = window.prompt('Pegá la URL de la imagen')
  if (entrada === null) return
  const url = urlImagen(entrada.trim())
  if (!url) return avisar('Ingresá una dirección de imagen HTTP o HTTPS.')
  const enlace = document.createElement('span')
  enlace.className = 'link-magico-img'
  enlace.dataset.imgUrl = url
  enlace.textContent = texto
  recuperarSeleccion()
  document.execCommand('insertHTML', false, enlace.outerHTML)
  recordarSeleccion()
  leerHoja()
}

const previewUrl = ref('')
const previewRef = ref(null)
const posicion = reactive({ left: '0px', top: '0px' })
let enlaceHover = null
let cursorX = 0
let cursorY = 0
let timerHover

function ocultarVista() {
  clearTimeout(timerHover)
  enlaceHover = null
  previewUrl.value = ''
}

function situarVista() {
  if (!previewRef.value) return
  const { width, height } = previewRef.value.getBoundingClientRect()
  function limitar(cursor, lado, ventana) {
    const ideal = cursor + 16 + lado <= ventana - 8 ? cursor + 16 : cursor - lado - 16
    return Math.max(8, Math.min(ideal, ventana - lado - 8)) + 'px'
  }
  posicion.left = limitar(cursorX, width, window.innerWidth)
  posicion.top = limitar(cursorY, height, window.innerHeight)
}

function sobreEnlace(evento) {
  const enlace = evento.target.closest('.link-magico-img')
  if (!enlace) return
  const cambio = enlaceHover !== enlace
  if (!cambio && evento.clientX === cursorX && evento.clientY === cursorY) return
  if (cambio) ocultarVista()
  enlaceHover = enlace
  cursorX = evento.clientX
  cursorY = evento.clientY
  if (previewUrl.value) return situarVista()
  clearTimeout(timerHover)
  timerHover = setTimeout(async () => {
    previewUrl.value = urlImagen(enlace.dataset.imgUrl)
    await nextTick()
    situarVista()
  }, 600)
}

function salirDeEnlace(evento) {
  if (enlaceHover && !enlaceHover.contains(evento.relatedTarget)) ocultarVista()
}

async function copiarEnlace(evento) {
  const url = evento.target.closest('.link-magico-img')?.dataset.imgUrl
  if (!url) return
  if (window.matchMedia('(pointer: coarse)').matches) {
    ocultarVista()
    cursorX = evento.clientX
    cursorY = evento.clientY
    previewUrl.value = urlImagen(url)
    await nextTick()
    situarVista()
    timerHover = setTimeout(ocultarVista, 2300)
  }
  try {
    await navigator.clipboard.writeText(url)
    avisar('🔗 Enlace de imagen copiado')
  } catch {
    avisar('El navegador no permitió copiar el enlace.')
  }
}

onMounted(() => {
  watch(() => props.campaignId, cargarNotas, { immediate: true })
  document.addEventListener('selectionchange', recordarSeleccion)
  window.addEventListener('resize', situarVista)
  window.addEventListener('scroll', ocultarVista, true)
  window.addEventListener('beforeunload', protegerBorrador)
})

onBeforeUnmount(() => {
  contexto++
  for (const nota of notas.value) void guardar(nota)
  ocultarVista()
  clearTimeout(timerMensaje)
  document.removeEventListener('selectionchange', recordarSeleccion)
  window.removeEventListener('resize', situarVista)
  window.removeEventListener('scroll', ocultarVista, true)
  window.removeEventListener('beforeunload', protegerBorrador)
})
</script>

<template>
  <section class="layout-notas-base" :class="pantallaCompleta ? 'modo-full' : 'modo-incrustado'" aria-label="Notas del DM">
    <aside class="sidebar-notas">
      <header class="cabecera-notas">
        <NuxtLink v-if="pantallaCompleta" class="volver-campana" :to="`/campanas/${campaignId}`">
          ← Volver a la Campaña
        </NuxtLink>
        <div class="acciones-notas">
          <h2>Grimorio</h2>
          <button type="button" class="nueva-nota" :disabled="cargando || creando || errorCarga" @click="crearNota">
            + Nueva Nota
          </button>
        </div>
      </header>

      <div class="lista-pergaminos" aria-label="Pergaminos">
        <p v-if="cargando" role="status">Cargando notas…</p>
        <div v-else-if="errorCarga" role="alert">
          <p>No se pudieron cargar las notas.</p>
          <button type="button" @click="cargarNotas">Reintentar</button>
        </div>
        <p v-else-if="!notas.length">El grimorio está vacío.</p>
        <div v-for="nota in notas" :key="nota.id" class="fila-nota" :class="{ elegida: activa === nota }">
          <button type="button" class="elegir-nota" :aria-current="activa === nota ? 'true' : undefined"
            :title="nota.titulo" @click="activa = nota">
            {{ nota.titulo || 'Sin título' }}
          </button>
          <span v-if="nota.error" class="fallo" title="Cambios sin guardar" aria-label="Cambios sin guardar">!</span>
          <button type="button" class="borrar-nota" :disabled="nota.borrando"
            :aria-label="`Eliminar ${nota.titulo || 'nota'}`" title="Eliminar nota" @click="borrarNota(nota)">×</button>
        </div>
      </div>
    </aside>

    <div v-if="activa" :key="activa.id" class="area-editor">
      <div class="toolbar-editor">
        <div class="fila-titulo">
          <input ref="tituloInputRef" type="text" class="titulo-pergamino" aria-label="Título de la nota"
            placeholder="Sin título" :disabled="activa.borrando" :value="activa.titulo" @input="editar('titulo', $event.target.value)">
          <span class="estado-guardado" role="status" aria-live="polite">
            <button v-if="activa.error" type="button" class="fallo" @click="guardar(activa)">Error · Reintentar</button>
            <span v-else-if="activa.guardada !== activa.version" class="guardando">Guardando…</span>
            <span v-else>✓ Guardado</span>
          </span>
        </div>
        <div class="herramientas" role="group" aria-label="Formato de texto">
          <button type="button" aria-label="Negrita" title="Negrita" @mousedown.prevent="recordarSeleccion"
            @click="formato('bold')"><b>B</b></button>
          <label class="control-color" title="Color del texto">
            <span>Color</span>
            <input type="color" aria-label="Color del texto" :value="color" @pointerdown="recordarSeleccion"
              @change="color = $event.target.value; formato('foreColor', color)">
          </label>
          <button type="button" @mousedown.prevent="recordarSeleccion" @click="insertarImagen">✨ Texto → Imagen</button>
        </div>
      </div>

      <div class="contenedor-hoja">
        <div ref="editorRef" class="hoja-papel-editor" :contenteditable="!activa.borrando" role="textbox"
          aria-multiline="true" aria-label="Contenido de la nota" data-placeholder="Escribí tus notas de campaña…"
          @input="leerHoja" @paste.prevent="pegar" @drop.prevent
          @mouseup="recordarSeleccion" @keyup="recordarSeleccion" @blur="recordarSeleccion"
          @mouseover="sobreEnlace" @mousemove="sobreEnlace" @mouseout="salirDeEnlace" @click="copiarEnlace"></div>
      </div>
    </div>
    <div v-else class="area-editor vacia">
      <p v-if="!cargando && !errorCarga">Creá un pergamino para empezar.</p>
    </div>

    <Teleport to="body">
      <div v-if="previewUrl" ref="previewRef" class="visor-flotante" :style="posicion">
        <img :src="previewUrl" alt="Imagen vinculada al pergamino" @error="ocultarVista">
      </div>
      <div v-if="mensaje" class="aviso-notas" role="status">{{ mensaje }}</div>
    </Teleport>
  </section>
</template>

<style scoped>
.layout-notas-base {
  display: flex;
  min-width: 0;
  overflow: hidden;
  background: #050505;
  color: #e2e8f0;
  font-family: 'Inter', sans-serif;
  color-scheme: dark;
}
.layout-notas-base, .layout-notas-base *, .visor-flotante, .aviso-notas { box-sizing: border-box; }
.modo-incrustado {
  width: 100%;
  height: 700px;
  flex-shrink: 0;
  border: 1px solid #1e293b;
  border-radius: 8px;
  box-shadow: 0 8px 24px #0008;
}
.modo-full { position: fixed; inset: 0; width: 100vw; height: 100vh; margin: 0; }

.sidebar-notas {
  display: flex;
  flex-direction: column;
  flex: 0 0 clamp(205px, 22%, 285px);
  min-height: 0;
  min-width: 0;
  background: #0a0a0c;
  border-right: 1px solid #1e293b;
}
.cabecera-notas, .toolbar-editor { padding: 14px 16px; border-bottom: 1px solid #1e293b; }
.cabecera-notas { flex-shrink: 0; }
.acciones-notas, .fila-titulo, .herramientas, .fila-nota, .control-color {
  display: flex;
  align-items: center;
  gap: 8px;
}
.acciones-notas { flex-wrap: wrap; justify-content: space-between; }
.cabecera-notas h2, .titulo-pergamino, .vacia p {
  margin: 0;
  font-family: 'Cinzel', serif;
  font-weight: 600;
}
.cabecera-notas h2 { font-size: 1.1rem; color: #facc15; }
.volver-campana { display: inline-block; margin-bottom: 12px; color: #94a3b8; font-size: .84rem; }
.volver-campana:hover { color: #facc15; }
.layout-notas-base button, .control-color {
  padding: 5px 9px;
  border: 1px solid #334155;
  border-radius: 5px;
  background: #111115;
  color: inherit;
  font: inherit;
  font-size: .84rem;
  cursor: pointer;
}
.layout-notas-base button:disabled { opacity: .55; cursor: wait; }
.layout-notas-base :is(button, input, a):focus-visible, .hoja-papel-editor:focus-visible {
  outline: 2px solid #60a5fa;
  outline-offset: -2px;
}
.layout-notas-base .nueva-nota { border-color: #b45309; color: #facc15; background: #281b0d; }
.layout-notas-base .nueva-nota:hover { border-color: #f59e0b; }
.lista-pergaminos, .contenedor-hoja { scrollbar-color: #334155 #0a0a0c; scrollbar-width: thin; }
.lista-pergaminos { flex: 1; min-height: 0; overflow-y: auto; padding: 12px; }
.lista-pergaminos p { margin: 6px 0; color: #94a3b8; font-size: .87rem; }
.fila-nota { margin-bottom: 6px; padding-right: 4px; gap: 0; border: 1px solid #27272a; border-radius: 6px; }
.fila-nota.elegida { border-color: #b45309; background: #20180e; color: #facc15; }
.fila-nota button { background: transparent; border-color: transparent; }
.fila-nota .elegir-nota {
  flex: 1;
  min-width: 0;
  padding: 9px;
  overflow: hidden;
  text-align: left;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.fila-nota .borrar-nota, .layout-notas-base .fallo { color: #fca5a5; }
.fila-nota .borrar-nota:hover { background: #7f1d1d; color: white; }

.area-editor {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
  min-height: 0;
  overflow: hidden;
  background: #070709;
}
.toolbar-editor { flex-shrink: 0; background: #0a0a0c; }
.fila-titulo { justify-content: space-between; }
.titulo-pergamino {
  flex: 1;
  min-width: 0;
  padding: 5px 4px;
  font-size: 1.2rem;
  border: 0;
  background: transparent;
  color: #facc15;
}
.estado-guardado { flex-shrink: 0; font-size: .78rem; color: #94b6a6; }
.guardando { color: #f59e0b; }
.herramientas { margin-top: 8px; flex-wrap: wrap; }
.herramientas button:hover, .control-color:focus-within { border-color: #60a5fa; }
.control-color { gap: 5px; }
.control-color input { display: block; width: 22px; height: 17px; padding: 0; border: 0; cursor: pointer; }
.contenedor-hoja {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  overscroll-behavior: contain;
  padding: clamp(10px, 2vw, 28px);
}
.hoja-papel-editor {
  width: 100%;
  max-width: 880px;
  height: auto;
  min-height: 100%;
  margin: 0 auto;
  padding: clamp(16px, 3vw, 40px);
  border: 1px solid #27272a;
  border-radius: 6px;
  background: #0a0a0c;
  color: #e2e8f0;
  font-size: 1rem;
  line-height: 1.7;
  white-space: pre-wrap;
  word-wrap: break-word;
  overflow-wrap: break-word;
  cursor: text;
}
.hoja-papel-editor:empty::before { content: attr(data-placeholder); color: #8490a1; pointer-events: none; }
.hoja-papel-editor :deep(pre) { white-space: pre-wrap; }
.hoja-papel-editor :deep(.link-magico-img) {
  color: #60a5fa;
  text-decoration: underline dotted;
  text-underline-offset: 3px;
  cursor: pointer;
}
.vacia { align-items: center; justify-content: center; padding: 16px; text-align: center; color: #94a3b8; }
.visor-flotante, .aviso-notas {
  position: fixed;
  z-index: 9999;
  pointer-events: none;
  background: #111115;
  border: 1px solid #b45309;
  border-radius: 8px;
  box-shadow: 0 8px 24px #000b;
}
.visor-flotante {
  width: min(320px, calc(100vw - 16px));
  height: min(240px, calc(100vh - 16px));
  overflow: hidden;
}
.visor-flotante img { display: block; width: 100%; height: 100%; object-fit: contain; }
.aviso-notas {
  bottom: 16px;
  left: 50%;
  transform: translateX(-50%);
  width: max-content;
  max-width: calc(100vw - 32px);
  padding: 10px 16px;
  color: #fef3c7;
  font: .9rem 'Inter', sans-serif;
}

@media (max-width: 680px) {
  .layout-notas-base { flex-direction: column; }
  .sidebar-notas { flex: 0 0 auto; max-height: 32%; border-right: 0; border-bottom: 1px solid #334155; }
  .cabecera-notas, .toolbar-editor { padding: 8px 12px; }
  .lista-pergaminos { flex: 0 1 auto; padding: 6px 12px; }
  .volver-campana { margin-bottom: 6px; }
  .titulo-pergamino { font-size: 1rem; }
}

@media (max-width: 680px) {
  .modo-full { height: 100dvh; }
  .lista-pergaminos { display: flex; gap: 6px; overflow-x: auto; overflow-y: hidden; }
  .fila-nota { flex: 0 0 auto; max-width: 220px; margin: 0; }
  .fila-nota button, .acciones-notas button, .herramientas button { min-height: 38px; }
  .hoja-papel-editor { padding: 14px; }
  .titulo-pergamino { font-size: 16px; }
}
@media (max-height: 480px) and (orientation: landscape) {
  .modo-full { flex-direction: row; height: 100dvh; }
  .modo-full .sidebar-notas { flex: 0 0 165px; max-height: 100%; }
  .modo-full .lista-pergaminos { display: block; overflow-y: auto; }
}
</style>
