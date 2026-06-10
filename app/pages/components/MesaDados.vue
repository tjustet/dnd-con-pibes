<script setup>
import { ref, defineExpose } from 'vue'

const props = defineProps({
  jugador: { type: String, default: 'Héroe' }
})

const abierto = ref(false)
const expandido = ref(false)
const tirando = ref(false)
const historial = ref([])
const tiradaActual = ref(null)

// El "Pool" manual de dados que el usuario va armando
const poolSeleccionado = ref([])
// Los dados que se están animando/mostrando en pantalla (ahora guardan {caras, valor})
const dadosEnMesa = ref([])

const cerrarMesa = () => {
  expandido.value = false
}

// ----------------------------------------------------
// LÓGICA 1: Tiradas desde la ficha de personaje
// ----------------------------------------------------
const tirar = (titulo, cantidad, caras, bono) => {
  const cantNum = parseInt(cantidad) || 1
  const carasNum = parseInt(caras) || 20
  const bonoNum = parseInt(bono) || 0

  // Armamos un arreglo con las caras pedidas (ej: si son 2d8, queda [8, 8])
  const dadosPedir = Array(cantNum).fill(carasNum)
  ejecutarTirada(titulo, dadosPedir, bonoNum)
}

// ----------------------------------------------------
// LÓGICA 2: Tiradas manuales desde el menú custom
// ----------------------------------------------------
const agregarDadoAlPool = (caras) => poolSeleccionado.value.push(caras)
const limpiarPool = () => poolSeleccionado.value = []

const tirarPoolManual = () => {
  if (poolSeleccionado.value.length === 0) return
  ejecutarTirada('Tirada Manual', [...poolSeleccionado.value], 0)
  limpiarPool() // Limpiamos la mano después de tirar
}

// ----------------------------------------------------
// MOTOR FÍSICO Y ANIMACIÓN CORE
// ----------------------------------------------------
const ejecutarTirada = (titulo, arrayDeCaras, bonoNum) => {
  tiradaActual.value = { titulo, bono: bonoNum, total: 0 }
  expandido.value = true
  tirando.value = true
  
  // Animación giratoria inicial
  const intervalo = setInterval(() => {
    dadosEnMesa.value = arrayDeCaras.map(caras => ({
      caras: caras,
      valor: Math.floor(Math.random() * caras) + 1
    }))
  }, 100)

  // Detener y calcular resultado real
  setTimeout(() => {
    clearInterval(intervalo)
    
    let suma = 0
    const resultadosFinales = arrayDeCaras.map(caras => {
      const v = Math.floor(Math.random() * caras) + 1
      suma += v
      return { caras, valor: v }
    })
    
    dadosEnMesa.value = resultadosFinales
    tiradaActual.value.total = suma + bonoNum
    tirando.value = false

    // Lógica para Críticos/Pifias (solo si es 1 solo d20)
    const esCritico = (arrayDeCaras.length === 1 && arrayDeCaras[0] === 20 && resultadosFinales[0].valor === 20)
    const esPifia = (arrayDeCaras.length === 1 && arrayDeCaras[0] === 20 && resultadosFinales[0].valor === 1)

    historial.value.unshift({
      id: Date.now(),
      jugador: props.jugador || 'Desconocido',
      titulo: titulo,
      resumenDados: resultadosFinales.map(d => `d${d.caras}[${d.valor}]`).join(', '),
      bono: bonoNum,
      total: tiradaActual.value.total,
      critico: esCritico,
      pifia: esPifia
    })

    if(historial.value.length > 20) historial.value.pop()
  }, 1500)
}

// Exponemos la función antigua para que la hoja de PJ no se rompa
defineExpose({ tirar })
</script>

<template>
  <div class="mesa-root">
    
    <div v-if="!expandido" class="fab-d20" @click="expandido = true" title="Abrir Mesa de Dados">
      <img src="./dadoD20.png" alt="Dado" class="img-d20" />
      <div v-if="!imgLoaded" class="fab-d20-fallback"></div> </div>

    <Transition name="fade-mesa">
      <div v-if="expandido" class="overlay-bg" @click.self="cerrarMesa">
        <div class="mesa-contenedor">
          <button class="btn-cerrar" @click="cerrarMesa" title="Minimizar">✖</button>

          <div class="panel-historial">
            <h3 class="titulo-historial">Historial de Tiradas</h3>
            <div class="lista-historial">
              <div v-for="item in historial" :key="item.id" class="item-historial" :class="{'crit-bg': item.critico, 'pif-bg': item.pifia}">
                <div class="hist-header">
                  <span class="hist-jugador">{{ item.jugador }}</span>
                  <span class="hist-titulo">{{ item.titulo }}</span>
                </div>
                <div class="hist-body">
                  <div class="hist-datos">
                    <span>{{ item.resumenDados }}</span>
                    <span class="hist-bono">Bono: {{ item.bono >= 0 ? '+' : '' }}{{ item.bono }}</span>
                  </div>
                  <div class="hist-total" :class="{'texto-crit': item.critico, 'texto-pif': item.pifia}">{{ item.total }}</div>
                </div>
              </div>
              <p v-if="historial.length === 0" class="texto-vacio">El registro está vacío.</p>
            </div>
          </div>

          <div class="panel-tirada">
            <h2 class="titulo-tirada-actual">{{ tiradaActual?.titulo || 'Mesa Preparada' }}</h2>
            
            <div class="zona-dados">
              <div v-for="(dado, idx) in dadosEnMesa" :key="idx" 
                   class="dado-3d" 
                   :class="{'animando-dado': tirando, ['dado-d'+dado.caras]: true}">
                <span class="numero-dado">{{ dado.valor }}</span>
              </div>
            </div>

            <Transition name="slide-up">
              <div v-if="!tirando && tiradaActual && dadosEnMesa.length > 0" class="zona-resultados">
                <div class="resultado-matematica">
                  <span class="math-dados">{{ dadosEnMesa.map(d=>d.valor).join(' + ') }}</span>
                  <span v-if="tiradaActual.bono != 0" class="math-bono">
                    {{ tiradaActual.bono >= 0 ? '+' : '-' }} {{ Math.abs(tiradaActual.bono) }}
                  </span>
                </div>
                <div class="resultado-gigante">{{ tiradaActual.total }}</div>
              </div>
            </Transition>

            <div class="constructor-manual" :class="{'deshabilitado': tirando}">
              <div class="botones-dados">
                <button @click="agregarDadoAlPool(4)" class="btn-dado-add">d4</button>
                <button @click="agregarDadoAlPool(6)" class="btn-dado-add">d6</button>
                <button @click="agregarDadoAlPool(8)" class="btn-dado-add">d8</button>
                <button @click="agregarDadoAlPool(10)" class="btn-dado-add">d10</button>
                <button @click="agregarDadoAlPool(12)" class="btn-dado-add">d12</button>
                <button @click="agregarDadoAlPool(20)" class="btn-dado-add d20-add">d20</button>
                <button @click="agregarDadoAlPool(100)" class="btn-dado-add">d100</button>
              </div>
              
              <div class="pool-visual">
                <div class="pool-items">
                  <span v-if="poolSeleccionado.length === 0" class="texto-gris">Seleccioná dados para armar la tirada...</span>
                  <span v-for="(d, i) in poolSeleccionado" :key="i" class="badge-pool">d{{d}}</span>
                </div>
                <div class="pool-acciones" v-if="poolSeleccionado.length > 0">
                  <button @click="limpiarPool" class="btn-limpiar">Limpiar</button>
                  <button @click="tirarPoolManual" class="btn-tirar-pool">ROLL</button>
                </div>
              </div>
            </div>

          </div>
        </div>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@700&family=Inter:wght@400;600;800&display=swap');

/* BOTÓN FLOTANTE (FAB) */
.mesa-root { z-index: 9999; }
.fab-d20 { position: fixed; bottom: 30px; right: 30px; width: 65px; height: 65px; background: #0f172a; border: 2px solid #3b82f6; border-radius: 50%; display: flex; align-items: center; justify-content: center; cursor: pointer; box-shadow: 0 5px 15px rgba(0,0,0,0.8), 0 0 20px rgba(59,130,246,0.3); transition: transform 0.2s, box-shadow 0.2s; z-index: 10000; overflow: hidden; }
.fab-d20:hover { transform: scale(1.1) rotate(15deg); box-shadow: 0 10px 25px rgba(0,0,0,0.9), 0 0 30px rgba(59,130,246,0.6); }
.img-d20 { width: 100%; height: 100%; object-fit: cover; }
.fab-d20-fallback { font-size: 2rem; position: absolute; } /* Por si falla la imagen */

/* OVERLAY Y CONTENEDOR */
.overlay-bg { position: fixed; inset: 0; background: rgba(5, 5, 5, 0.85); backdrop-filter: blur(8px); display: flex; align-items: center; justify-content: center; z-index: 9999; }
.mesa-contenedor { width: 1050px; max-width: 95vw; height: 650px; max-height: 90vh; background: #0a0a0c; border: 2px solid #3b82f6; border-radius: 12px; display: flex; overflow: hidden; position: relative; box-shadow: 0 20px 50px rgba(0,0,0,0.8), inset 0 0 30px rgba(59,130,246,0.1); }
.btn-cerrar { position: absolute; top: 15px; right: 20px; background: rgba(239, 68, 68, 0.2); color: #fca5a5; border: 1px solid #ef4444; width: 35px; height: 35px; border-radius: 50%; font-size: 1.2rem; cursor: pointer; display: flex; align-items: center; justify-content: center; z-index: 10; transition: 0.2s; }
.btn-cerrar:hover { background: #ef4444; color: white; transform: scale(1.1); }

/* HISTORIAL */
.panel-historial { width: 350px; background: #111; border-right: 2px solid #1e293b; display: flex; flex-direction: column; padding: 1.5rem; }
.titulo-historial { color: #facc15; font-family: 'Cinzel', serif; font-size: 1.2rem; margin-top: 0; margin-bottom: 1.5rem; border-bottom: 1px solid #1e293b; padding-bottom: 0.5rem; text-align: center; }
.lista-historial { display: flex; flex-direction: column; gap: 1rem; overflow-y: auto; padding-right: 0.5rem; flex-grow: 1; }
.lista-historial::-webkit-scrollbar { width: 4px; } .lista-historial::-webkit-scrollbar-thumb { background: #334155; border-radius: 4px; }
.item-historial { background: rgba(30, 41, 59, 0.5); border: 1px solid #334155; border-radius: 8px; padding: 0.8rem; border-left: 4px solid #3b82f6; }
.item-historial.crit-bg { border-left-color: #facc15; background: rgba(250, 204, 21, 0.1); }
.item-historial.pif-bg { border-left-color: #ef4444; background: rgba(239, 68, 68, 0.1); }
.hist-header { display: flex; flex-direction: column; margin-bottom: 0.5rem; }
.hist-jugador { font-size: 0.65rem; color: #94a3b8; font-weight: bold; text-transform: uppercase; }
.hist-titulo { color: white; font-weight: bold; font-size: 0.9rem; }
.hist-body { display: flex; justify-content: space-between; align-items: flex-end; }
.hist-datos { display: flex; flex-direction: column; font-size: 0.7rem; color: #cbd5e1; font-family: monospace; }
.hist-bono { color: #93c5fd; }
.hist-total { font-family: 'Cinzel', serif; font-size: 2rem; color: #facc15; font-weight: bold; line-height: 1; text-shadow: 0 0 10px rgba(250,204,21,0.3); }
.texto-crit { color: #facc15 !important; } .texto-pif { color: #fca5a5 !important; }
.texto-vacio { font-style: italic; color: #475569; text-align: center; padding: 1rem; margin: 0; }

/* PANEL TIRADA 3D */
.panel-tirada { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; position: relative; padding: 2rem; background: radial-gradient(circle at center, #1e293b 0%, #0a0a0c 100%); padding-bottom: 150px; }
.titulo-tirada-actual { position: absolute; top: 40px; font-family: 'Cinzel', serif; font-size: 2.5rem; color: white; text-align: center; text-shadow: 0 5px 15px rgba(0,0,0,0.8); margin: 0; width: 80%; }
.zona-dados { display: flex; flex-wrap: wrap; justify-content: center; gap: 1.5rem; }
.dado-3d { width: 100px; height: 100px; display: flex; align-items: center; justify-content: center; color: white; font-size: 2.5rem; font-family: 'Inter', sans-serif; font-weight: 800; background: linear-gradient(135deg, #2563eb, #1e3a8a); box-shadow: inset 0 0 15px rgba(0,0,0,0.8), 0 10px 20px rgba(0,0,0,0.5); text-shadow: 2px 2px 4px rgba(0,0,0,0.8); }

.dado-d20, .dado-d12, .dado-d100, .dado-d10, .dado-d8 { clip-path: polygon(50% 0%, 100% 25%, 100% 75%, 50% 100%, 0% 75%, 0% 25%); }
.dado-d6 { border-radius: 12px; }
.dado-d4 { clip-path: polygon(50% 0%, 0% 100%, 100% 100%); align-items: flex-end; padding-bottom: 10px; font-size: 2rem; }

.animando-dado { animation: shake-roll 0.4s infinite linear, color-pulse 0.4s infinite alternate; }
@keyframes shake-roll { 0% { transform: rotate(0deg) scale(1) translateY(0); } 25% { transform: rotate(25deg) scale(1.1) translateY(-15px); } 50% { transform: rotate(0deg) scale(1) translateY(0); } 75% { transform: rotate(-25deg) scale(1.1) translateY(15px); } 100% { transform: rotate(0deg) scale(1) translateY(0); } }
@keyframes color-pulse { from { filter: brightness(1); } to { filter: brightness(1.5) drop-shadow(0 0 15px #3b82f6); } }

/* RESULTADOS */
.zona-resultados { display: flex; flex-direction: column; align-items: center; position: absolute; bottom: 160px; background: rgba(0,0,0,0.6); padding: 1.5rem 3rem; border-radius: 16px; border: 1px solid #334155; backdrop-filter: blur(5px); }
.resultado-matematica { font-family: monospace; font-size: 1.5rem; color: #94a3b8; display: flex; gap: 1rem; align-items: center; margin-bottom: 0.5rem; }
.math-dados { color: white; background: #1e293b; padding: 0.2rem 0.8rem; border-radius: 8px; }
.math-bono { color: #fca5a5; font-weight: bold; }
.resultado-gigante { font-family: 'Cinzel', serif; font-size: 6rem; font-weight: bold; color: #facc15; line-height: 1; text-shadow: 0 0 30px rgba(250,204,21,0.4); }

/* CONSTRUCTOR MANUAL (ABAjO) */
.constructor-manual { position: absolute; bottom: 0; left: 0; right: 0; background: #0f172a; border-top: 1px solid #1e293b; padding: 1rem 2rem; display: flex; flex-direction: column; gap: 1rem; transition: opacity 0.3s; }
.constructor-manual.deshabilitado { opacity: 0.5; pointer-events: none; }

.botones-dados { display: flex; justify-content: center; gap: 0.8rem; }
.btn-dado-add { background: #1e293b; border: 1px solid #334155; color: white; font-family: 'Cinzel', serif; font-weight: bold; width: 50px; height: 50px; border-radius: 8px; cursor: pointer; transition: 0.2s; font-size: 1rem; }
.btn-dado-add:hover { background: #3b82f6; border-color: #60a5fa; transform: translateY(-3px); }
.d20-add { background: #1e3a8a; border-color: #3b82f6; color: #facc15; }

.pool-visual { display: flex; align-items: center; justify-content: space-between; background: #050505; border: 1px dashed #334155; border-radius: 8px; padding: 0.5rem 1rem; min-height: 50px; }
.pool-items { display: flex; gap: 0.5rem; flex-wrap: wrap; flex-grow: 1; }
.badge-pool { background: #1e3a8a; color: white; font-family: monospace; font-size: 0.8rem; font-weight: bold; padding: 0.3rem 0.6rem; border-radius: 4px; border: 1px solid #3b82f6; }
.texto-gris { color: #64748b; font-style: italic; font-size: 0.9rem; }
.pool-acciones { display: flex; gap: 0.5rem; }
.btn-limpiar { background: transparent; border: 1px solid #475569; color: #cbd5e1; padding: 0.4rem 0.8rem; border-radius: 4px; cursor: pointer; font-weight: bold; }
.btn-limpiar:hover { background: #ef4444; color: white; border-color: #ef4444; }
.btn-tirar-pool { background: #b45309; border: 1px solid #d97706; color: white; padding: 0.4rem 1.5rem; border-radius: 4px; cursor: pointer; font-weight: bold; font-family: 'Cinzel', serif; font-size: 1.1rem; }
.btn-tirar-pool:hover { background: #d97706; transform: scale(1.05); }

.fade-mesa-enter-active, .fade-mesa-leave-active { transition: opacity 0.3s ease; }
.fade-mesa-enter-from, .fade-mesa-leave-to { opacity: 0; }
.slide-up-enter-active { transition: all 0.5s cubic-bezier(0.175, 0.885, 0.32, 1.275); }
.slide-up-enter-from { opacity: 0; transform: translateY(50px) scale(0.8); }
</style>