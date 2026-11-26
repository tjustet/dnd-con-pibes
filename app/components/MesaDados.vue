<script setup>
import LanzadorDados from './dados/LanzadorDados.vue'
const { avisar } = useAvisos()
let montado = true
const supabase = useSupabaseClient()

const props = defineProps({
  jugador: String,
  campanaId: [String, Number]
})

const panelAbierto = ref(false)
const historialCompartido = ref([])
let canalMesa = null

const { tirada, tirando, lanzar } = useTiradaAnimada()
const poolManual = ref([])
const bonoManual = ref(0)

// Hacer scroll automático al último mensaje
const historialRef = ref(null)
const scrollearAbajo = () => {
  nextTick(() => {
    if (historialRef.value) historialRef.value.scrollTop = 0 // Como el array está invertido, el top es el más nuevo
  })
}

// 1. CARGA INICIAL Y WEBSOCKETS
const conectarMesa = async () => {
  if (!props.campanaId) return

  // Traer historial actual
  const { data } = await supabase.from('campana_publicada').select('historial_dados').eq('id', props.campanaId).single()
  if (data && data.historial_dados) {
    historialCompartido.value = data.historial_dados.filter(h => !h.oculto)
  }

  // Escuchar en tiempo real
  if (!montado) return
  canalMesa = supabase.channel('jugador_dados_' + props.jugador)
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'campana_publicada', filter: `id=eq.${props.campanaId}` }, (payload) => {
      if (payload.new.historial_dados) {
        historialCompartido.value = payload.new.historial_dados.filter(h => !h.oculto)
        scrollearAbajo()
      }
    }).subscribe()
}

onMounted(() => {
  if (props.campanaId) conectarMesa()
})

onUnmounted(() => {
  montado = false
  if (canalMesa) supabase.removeChannel(canalMesa)
})

async function ejecutarTirada(titulo, cantDados, caras, bono, efecto = null) {
  if (!props.campanaId) return avisar('Asigná el personaje a una campaña para compartir la tirada.')
  if (tirando.value) return
  const pool = Array.isArray(caras) ? caras : Array(Math.max(1, Math.min(100, parseInt(cantDados) || 1))).fill(Number(caras) || 20)
  panelAbierto.value = true
  const t = await lanzar(pool, bono, titulo, efecto)
  if (!t) return
  const registro = {
    id: t.id, tirador: props.jugador || 'Desconocido', titulo: t.titulo,
    dadosStr: t.dados.map(d => `d${d.caras}[${d.valor}]`).join(', '), bono: t.bono, total: t.total,
    oculto: false, targetAsignado: '', mostrarAsignador: false, efecto_vinculado: t.efecto
  }
  try {
    const historial = await anotarTirada(supabase, props.campanaId, registro)
    if (montado) historialCompartido.value = historial.filter(h => !h.oculto)
  } catch (e) { avisar(e.message, true) }
}

defineExpose({ tirar: ejecutarTirada })

function tirarManual() {
  if (tirando.value || !poolManual.value.length) return
  ejecutarTirada('Tirada manual', poolManual.value.length, poolManual.value, bonoManual.value)
  poolManual.value = []
}
function repetir() {
  const t = tirada.value
  if (t) ejecutarTirada(t.titulo, t.dados.length, t.dados.map(d => d.caras), t.bono, t.efecto)
}
function quitar(caras) {
  const i = poolManual.value.lastIndexOf(caras)
  if (i >= 0) poolManual.value.splice(i,1)
}
function limpiar() {
  poolManual.value = []
  bonoManual.value = 0
  tirada.value = null
}
const botonMesa = ref(null)
function cerrar() {
  panelAbierto.value = false
  botonMesa.value?.focus()
}
</script>

<template>
  <div class="mesa-flotante-wrapper" :class="{ desplegada: panelAbierto }" @keydown.esc.stop="cerrar">
    <button ref="botonMesa" type="button" class="btn-abrir-mesa" :aria-expanded="panelAbierto"
      @click="panelAbierto = !panelAbierto">{{ panelAbierto ? 'Cerrar dados' : 'Mesa de dados' }}</button>
    <Transition name="abrir-dados">
      <div v-if="panelAbierto" class="panel-mesa-global">
        <LanzadorDados titulo="Mesa de dados" :pool="poolManual" :tirada="tirada" :tirando="tirando" v-model:bono="bonoManual"
          @agregar="poolManual.push($event)" @quitar="quitar" @limpiar="limpiar" @tirar="tirarManual" @repetir="repetir" />
        <h3>Historial de tiradas</h3>
      <div class="historial-zona" ref="historialRef">
        <div v-for="h in historialCompartido" :key="h.id" class="hist-item" :class="{'mi-tirada': h.tirador === props.jugador}">
          <div class="h-head">
            <span class="h-quien">{{ h.tirador }}</span>
            <span class="h-que">{{ h.titulo }}</span>
          </div>
          <div class="h-dados">{{ h.dadosStr }}</div>
          <div class="h-foot">
            <span class="h-bono">Bono: {{ h.bono >= 0 ? '+' : '' }}{{ h.bono }}</span>
            <span class="h-total">{{ h.total }}</span>
          </div>
        </div>
        <div v-if="historialCompartido.length === 0" class="vacio">No hay tiradas todavía...</div>
      </div>

      </div>
    </Transition>
  </div>
</template>

<style scoped>
.mesa-flotante-wrapper { position: fixed; right: 12px; bottom: max(12px,env(safe-area-inset-bottom)); z-index: 9999; display: grid; justify-items: end; gap: .45rem; font-family: Inter,sans-serif; }
.mesa-flotante-wrapper.desplegada { z-index: 10001; }
.btn-abrir-mesa { grid-row: 2; border: 1px solid #8b7356; border-radius: 22px; padding: .55rem 1rem; min-height: 44px; font: 600 .94rem/1.25 Cinzel,Georgia,serif; color: #f6dfaf; background: linear-gradient(145deg,#302735,#181720); box-shadow: 0 4px 16px #0008; cursor: pointer; }
.btn-abrir-mesa[aria-expanded=true] { background: #27222a; }
.panel-mesa-global { grid-row: 1; width: min(26rem, calc(100vw - 24px)); max-height: calc(100vh - 78px); max-height: calc(100dvh - 78px - env(safe-area-inset-bottom)); overflow: auto; overscroll-behavior: contain; scrollbar-color: #5f515b #17151c; background: #141317; border: 1px solid #6c5a4b; border-radius: 12px; box-shadow: 0 14px 40px #000a; transform-origin: bottom right; }
.panel-mesa-global h3 { font: 600 .98rem/1.4 Cinzel,Georgia,serif; padding: .6rem 1rem 0; color: #decbaa; border-top: 1px solid #3d353b; }
.abrir-dados-enter-active,.abrir-dados-leave-active { transition: opacity .18s, transform .22s ease-out; }
.abrir-dados-enter-from,.abrir-dados-leave-to { opacity: 0; transform: translateY(.5rem) scale(.98); }
/* Historial */
.historial-zona { height: 11rem; background: #111; overflow-y: auto; padding: 1rem; display: flex; flex-direction: column; gap: 0.8rem; border-bottom: 2px solid #1e293b; }
.historial-zona::-webkit-scrollbar { width: 4px; }
.historial-zona::-webkit-scrollbar-thumb { background: #3b82f6; }
.vacio { text-align: center; color: #b0a8b8; font-style: italic; font-size: 0.9rem; margin-top: 1rem; }

.hist-item { background: rgba(30, 41, 59, 0.5); border-left: 3px solid #64748b; padding: 0.6rem; border-radius: 6px; }
.hist-item.mi-tirada { border-left-color: #facc15; background: rgba(250, 204, 21, 0.05); }
.h-head { display: flex; justify-content: space-between; margin-bottom: 0.3rem; align-items: center; }
.h-quien { font-size: 0.7rem; font-weight: bold; color: #cbd5e1; background: #1e293b; padding: 0.1rem 0.4rem; border-radius: 4px; }
.mi-tirada .h-quien { color: #facc15; background: rgba(250,204,21,0.2); }
.h-que { font-size: 0.8rem; color: #94a3b8; font-weight: bold; }
.h-dados { font-family: monospace; color: #a9a8bb; font-size: 0.8rem; margin-bottom: 0.4rem; }
.h-foot { display: flex; justify-content: space-between; align-items: flex-end; }
.h-bono { font-size: 0.75rem; color: #93c5fd; }
.h-total { font-family: 'Cinzel', serif; font-size: 1.5rem; font-weight: bold; color: white; line-height: 1; }

@media (max-width: 450px) {
  .btn-abrir-mesa { max-width: 44vw; }
  .historial-zona { height: 9rem; }
}
</style>
