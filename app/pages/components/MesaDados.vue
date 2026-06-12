<script setup>
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
const supabase = useSupabaseClient()

const props = defineProps({
  jugador: String,
  campanaId: [String, Number]
})

const panelAbierto = ref(false)
const historialCompartido = ref([])
let canalMesa = null

// Motor 3D y variables de tiro
const tirando = ref(false)
const dadosEnMesa = ref([])
const resultadoFinal = ref(0)
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
  const { data } = await supabase.from('campaigns').select('historial_dados').eq('id', props.campanaId).single()
  if (data && data.historial_dados) {
    historialCompartido.value = data.historial_dados.filter(h => !h.oculto)
  }

  // Escuchar en tiempo real
  canalMesa = supabase.channel('jugador_dados_' + props.jugador)
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'campaigns', filter: `id=eq.${props.campanaId}` }, (payload) => {
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
  if (canalMesa) supabase.removeChannel(canalMesa)
})

// 2. MOTOR DE TIRADAS
const ejecutarTirada = async (titulo, cantDados, caras, bonoNum, efecto_vinculado = null) => {
  if (!props.campanaId) {
    alert("Este personaje no está en ninguna campaña. No se pueden compartir los dados.")
    return
  }

  panelAbierto.value = true
  tirando.value = true
  resultadoFinal.value = 0
  
  const arrayCaras = Array(cantDados).fill(caras)

  // Animación 3D falsa
  const intervalo = setInterval(() => {
    dadosEnMesa.value = arrayCaras.map(c => ({ caras: c, valor: Math.floor(Math.random() * c) + 1 }))
  }, 100)

  // Resultado final después de 1 segundo
  setTimeout(async () => {
    clearInterval(intervalo)
    let suma = 0
    dadosEnMesa.value = arrayCaras.map(c => {
      const v = Math.floor(Math.random() * c) + 1
      suma += v
      return { caras: c, valor: v }
    })
    
    resultadoFinal.value = suma + bonoNum
    tirando.value = false

    const nuevaTirada = {
      id: Date.now(),
      tirador: props.jugador || 'Desconocido',
      titulo: titulo,
      dadosStr: dadosEnMesa.value.map(d => `d${d.caras}[${d.valor}]`).join(', '),
      bono: bonoNum,
      total: resultadoFinal.value,
      oculto: false, // Los jugadores nunca tiran oculto
      targetAsignado: '',
      mostrarAsignador: false,
      efecto_vinculado: efecto_vinculado
    }

    // Para evitar pisarse con otros, traemos el último historial justo antes de guardar
    const { data } = await supabase.from('campaigns').select('historial_dados').eq('id', props.campanaId).single()
    const histActual = data?.historial_dados || []
    const nuevoHist = [nuevaTirada, ...histActual].slice(0, 30) // Guardamos 30 max

    await supabase.from('campaigns').update({ historial_dados: nuevoHist }).eq('id', props.campanaId)

  }, 1000)
}

// 3. EXPORTAR PARA QUE LA FICHA LO USE
defineExpose({
  tirar: (titulo, cantDados, caras, bonoNum, efecto) => ejecutarTirada(titulo, cantDados, caras, bonoNum, efecto)
})

// Tiradas manuales desde el panel
const agregarDadoManual = (caras) => poolManual.value.push(caras)
const limpiarPool = () => { poolManual.value = []; bonoManual.value = 0; dadosEnMesa.value = []; resultadoFinal.value = 0 }
const tirarManual = () => {
  if (poolManual.value.length === 0) return
  ejecutarTirada('Tirada Manual', poolManual.value.length, poolManual.value[0], parseInt(bonoManual.value) || 0)
  poolManual.value = [] // Limpia después de tirar
}
</script>

<template>
  <div class="mesa-flotante-wrapper">
    <button class="btn-abrir-mesa" @click="panelAbierto = !panelAbierto" :class="{'abierto': panelAbierto}">
      🎲 Registro de Mesa
    </button>

    <div class="panel-mesa-global" :class="{'activo': panelAbierto}">
      
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

      <div class="tapete-zona">
        <div class="tapete-caida">
          <div v-for="(d, idx) in dadosEnMesa" :key="idx" class="dado-3d" :class="{'girando': tirando, ['d'+d.caras]: true}">
            {{ d.valor }}
          </div>
        </div>
        <div v-if="!tirando && resultadoFinal > 0" class="resultado-grande">{{ resultadoFinal }}</div>
      </div>

      <div class="controles-zona">
        <div class="botones-dados">
          <button @click="agregarDadoManual(4)">d4</button>
          <button @click="agregarDadoManual(6)">d6</button>
          <button @click="agregarDadoManual(8)">d8</button>
          <button @click="agregarDadoManual(10)">d10</button>
          <button @click="agregarDadoManual(12)">d12</button>
          <button @click="agregarDadoManual(20)" class="btn-d20">d20</button>
          <button @click="agregarDadoManual(100)">d100</button>
        </div>
        <div class="pool-accion">
          <div class="pool-view">
            <span v-if="poolManual.length === 0" class="txt-gris">Elige dados...</span>
            <span v-for="(p, i) in poolManual" :key="i" class="badge-dado">d{{p}}</span>
          </div>
          <div class="inputs-final">
            <input type="number" v-model="bonoManual" placeholder="+Bono" class="inp-bono" />
            <button class="btn-clean" @click="limpiarPool">✖</button>
            <button class="btn-roll" @click="tirarManual">TIRAR</button>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700&family=Inter:wght@400;600&display=swap');
input[type=number]::-webkit-inner-spin-button, input[type=number]::-webkit-outer-spin-button { -webkit-appearance: none; margin: 0; }

.mesa-flotante-wrapper { position: fixed; bottom: 20px; right: 20px; z-index: 9999; display: flex; flex-direction: column; align-items: flex-end; gap: 10px; font-family: 'Inter', sans-serif; }

.btn-abrir-mesa { background: #1e3a8a; border: 2px solid #3b82f6; color: white; padding: 0.8rem 1.5rem; border-radius: 30px; font-family: 'Cinzel', serif; font-weight: bold; font-size: 1.1rem; cursor: pointer; box-shadow: 0 5px 15px rgba(0,0,0,0.5); transition: 0.3s; }
.btn-abrir-mesa:hover { transform: translateY(-3px); box-shadow: 0 8px 20px rgba(59,130,246,0.4); }
.btn-abrir-mesa.abierto { background: #0f172a; border-color: #475569; color: #94a3b8; }

.panel-mesa-global { width: 350px; background: #0a0a0c; border: 2px solid #3b82f6; border-radius: 12px; display: flex; flex-direction: column; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.8); max-height: 0; opacity: 0; transition: 0.3s cubic-bezier(0.4, 0, 0.2, 1); pointer-events: none; }
.panel-mesa-global.activo { max-height: 700px; opacity: 1; pointer-events: auto; }

/* Historial */
.historial-zona { height: 250px; background: #111; overflow-y: auto; padding: 1rem; display: flex; flex-direction: column-reverse; gap: 0.8rem; border-bottom: 2px solid #1e293b; }
.historial-zona::-webkit-scrollbar { width: 4px; }
.historial-zona::-webkit-scrollbar-thumb { background: #3b82f6; }
.vacio { text-align: center; color: #475569; font-style: italic; font-size: 0.9rem; margin-top: 1rem; }

.hist-item { background: rgba(30, 41, 59, 0.5); border-left: 3px solid #64748b; padding: 0.6rem; border-radius: 6px; }
.hist-item.mi-tirada { border-left-color: #facc15; background: rgba(250, 204, 21, 0.05); }
.h-head { display: flex; justify-content: space-between; margin-bottom: 0.3rem; align-items: center; }
.h-quien { font-size: 0.7rem; font-weight: bold; color: #cbd5e1; background: #1e293b; padding: 0.1rem 0.4rem; border-radius: 4px; }
.mi-tirada .h-quien { color: #facc15; background: rgba(250,204,21,0.2); }
.h-que { font-size: 0.8rem; color: #94a3b8; font-weight: bold; }
.h-dados { font-family: monospace; color: #64748b; font-size: 0.8rem; margin-bottom: 0.4rem; }
.h-foot { display: flex; justify-content: space-between; align-items: flex-end; }
.h-bono { font-size: 0.75rem; color: #93c5fd; }
.h-total { font-family: 'Cinzel', serif; font-size: 1.5rem; font-weight: bold; color: white; line-height: 1; }

/* Tapete 3D */
.tapete-zona { position: relative; height: 180px; background: radial-gradient(circle at center, #1e293b, #050505); display: flex; align-items: center; justify-content: center; overflow: hidden; }
.tapete-caida { display: flex; flex-wrap: wrap; gap: 0.8rem; justify-content: center; padding: 1rem; }
.dado-3d { width: 50px; height: 50px; background: linear-gradient(135deg, #2563eb, #1e3a8a); color: white; display: flex; align-items: center; justify-content: center; font-family: 'Inter', sans-serif; font-size: 1.4rem; font-weight: bold; box-shadow: inset 0 0 10px rgba(0,0,0,0.8), 0 5px 10px rgba(0,0,0,0.6); }
.d20, .d12, .d100, .d10, .d8 { clip-path: polygon(50% 0%, 100% 25%, 100% 75%, 50% 100%, 0% 75%, 0% 25%); }
.d6 { border-radius: 8px; }
.d4 { clip-path: polygon(50% 0%, 0% 100%, 100% 100%); align-items: flex-end; padding-bottom: 5px; font-size: 1rem; }
.girando { animation: shake 0.3s infinite linear; }
@keyframes shake { 0% { transform: rotate(0deg) scale(1); } 25% { transform: rotate(25deg) scale(1.1); } 50% { transform: rotate(0deg) scale(1); } 75% { transform: rotate(-25deg) scale(1.1); } 100% { transform: rotate(0deg) scale(1); } }
.resultado-grande { position: absolute; bottom: 10px; font-family: 'Cinzel', serif; font-size: 3rem; color: #facc15; font-weight: bold; text-shadow: 0 0 15px rgba(250,204,21,0.6); background: rgba(0,0,0,0.7); padding: 0 1rem; border-radius: 8px; border: 1px solid #334155; }

/* Controles manuales */
.controles-zona { background: #0f172a; padding: 0.8rem; border-top: 1px solid #1e293b; display: flex; flex-direction: column; gap: 0.6rem; }
.botones-dados { display: flex; justify-content: center; gap: 0.4rem; }
.botones-dados button { background: #1e293b; border: 1px solid #334155; color: white; font-family: 'Cinzel', serif; font-weight: bold; padding: 0.4rem; border-radius: 4px; cursor: pointer; flex: 1; font-size: 0.8rem; }
.botones-dados button:hover { background: #3b82f6; }
.btn-d20 { background: #1e3a8a !important; color: #facc15 !important; border-color: #3b82f6 !important; }

.pool-accion { display: flex; flex-direction: column; gap: 0.5rem; background: #050505; border: 1px dashed #334155; padding: 0.5rem; border-radius: 6px; }
.pool-view { display: flex; gap: 0.3rem; flex-wrap: wrap; min-height: 22px; }
.badge-dado { background: #1e3a8a; border: 1px solid #3b82f6; color: white; padding: 0.1rem 0.4rem; border-radius: 4px; font-family: monospace; font-size: 0.7rem; }
.txt-gris { color: #475569; font-size: 0.8rem; font-style: italic; }
.inputs-final { display: flex; gap: 0.4rem; height: 35px; }
.inp-bono { width: 60px; background: #111; border: 1px solid #475569; color: white; text-align: center; border-radius: 4px; font-weight: bold; }
.btn-clean { background: transparent; border: 1px solid #ef4444; color: #fca5a5; border-radius: 4px; padding: 0 0.5rem; cursor: pointer; }
.btn-roll { flex-grow: 1; background: #b45309; border: 1px solid #d97706; color: white; font-family: 'Cinzel', serif; font-weight: bold; border-radius: 4px; cursor: pointer; font-size: 1.1rem; }
</style>