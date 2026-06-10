<script setup>
import { ref, defineExpose } from 'vue'

const props = defineProps({
  jugador: { type: String, default: 'Héroe' }
})

const abierto = ref(false)
const expandido = ref(false) // Controla si está en pantalla completa (false = abajo a la derecha)
const tirando = ref(false)
const historial = ref([])
const tiradaActual = ref(null)
const carasAnimadas = ref([])

const cerrarMesa = () => {
  abierto.value = false
  expandido.value = false
}

const tirar = (titulo, cantidad, caras, bono) => {
  const cantNum = parseInt(cantidad) || 1
  const carasNum = parseInt(caras) || 20
  const bonoNum = parseInt(bono) || 0

  tiradaActual.value = { titulo, cantidad: cantNum, caras: carasNum, bono: bonoNum, resultados: [], total: 0 }
  
  abierto.value = true
  tirando.value = true
  
  // Animación giratoria
  const intervalo = setInterval(() => {
    carasAnimadas.value = Array.from({ length: cantNum }, () => Math.floor(Math.random() * carasNum) + 1)
  }, 100)

  // Resultado final
  setTimeout(() => {
    clearInterval(intervalo)
    
    let suma = 0
    const resReales = []
    for(let i = 0; i < cantNum; i++){
      const d = Math.floor(Math.random() * carasNum) + 1
      resReales.push(d)
      suma += d
    }
    
    tiradaActual.value.resultados = resReales
    tiradaActual.value.total = suma + bonoNum
    carasAnimadas.value = resReales
    tirando.value = false

    // Identificar críticos (solo para d20)
    const esCritico = (carasNum === 20 && resReales[0] === 20 && cantNum === 1)
    const esPifia = (carasNum === 20 && resReales[0] === 1 && cantNum === 1)

    historial.value.unshift({
      id: Date.now(),
      jugador: props.jugador || 'Desconocido',
      titulo: titulo,
      caras: carasNum,
      resultadosStr: `[${resReales.join(', ')}]`,
      bono: bonoNum,
      total: tiradaActual.value.total,
      critico: esCritico,
      pifia: esPifia
    })

    if(historial.value.length > 20) historial.value.pop()

  }, 1500)
}

defineExpose({ tirar })
</script>

<template>
  <Transition name="fade-mesa">
    <div v-if="abierto" class="mesa-root" :class="expandido ? 'is-modal' : 'is-mini'">
      
      <div v-if="expandido" class="overlay-bg" @click="cerrarMesa"></div>

      <div v-if="expandido" class="mesa-contenedor">
        <button class="btn-accion btn-cerrar" @click="cerrarMesa" title="Cerrar">✖</button>
        <button class="btn-accion btn-minimizar" @click="expandido = false" title="Minimizar">🗕</button>

        <div class="panel-historial">
          <h3 class="titulo-historial"><i class="fa-solid fa-book-journal-whills"></i> Historial</h3>
          <div class="lista-historial">
            <div v-for="item in historial" :key="item.id" class="item-historial" :class="{'crit-bg': item.critico, 'pif-bg': item.pifia}">
              <div class="hist-header">
                <span class="hist-jugador">{{ item.jugador }}</span>
                <span class="hist-titulo">{{ item.titulo }}</span>
              </div>
              <div class="hist-body">
                <div class="hist-datos">
                  <span class="hist-dado">d{{ item.caras }} ➔ {{ item.resultadosStr }}</span>
                  <span class="hist-bono">Bono: {{ item.bono >= 0 ? '+' : '' }}{{ item.bono }}</span>
                </div>
                <div class="hist-total" :class="{'texto-crit': item.critico, 'texto-pif': item.pifia}">{{ item.total }}</div>
              </div>
            </div>
            <p v-if="historial.length === 0" class="texto-vacio">El registro está en blanco.</p>
          </div>
        </div>

        <div class="panel-tirada">
          <h2 class="titulo-tirada-actual">{{ tiradaActual?.titulo }}</h2>
          <div class="zona-dados">
            <div v-for="(num, idx) in carasAnimadas" :key="idx" 
                 class="dado-3d" 
                 :class="{'animando-dado': tirando, ['dado-d'+(tiradaActual?.caras || 20)]: true}">
              <span class="numero-dado">{{ num }}</span>
            </div>
          </div>
          <Transition name="slide-up">
            <div v-if="!tirando && tiradaActual" class="zona-resultados">
              <div class="resultado-matematica">
                <span class="math-dados">{{ tiradaActual.resultados.join(' + ') }}</span>
                <span v-if="tiradaActual.bono != 0" class="math-bono">
                  {{ tiradaActual.bono >= 0 ? '+' : '-' }} {{ Math.abs(tiradaActual.bono) }}
                </span>
              </div>
              <div class="resultado-gigante">
                {{ tiradaActual.total }}
              </div>
            </div>
          </Transition>
        </div>
      </div>

      <div v-else class="mesa-mini">
        <div class="mini-header">
          <span>🎲 Mesa de Dados</span>
          <div class="mini-controles">
            <button @click="expandido = true" title="Agrandar">⛶</button>
            <button @click="cerrarMesa" title="Cerrar">✖</button>
          </div>
        </div>

        <div class="mini-body">
          <div v-if="tirando" class="mini-zona-tirando">
            <span class="mini-tit-tirando">{{ tiradaActual?.titulo }}</span>
            <div class="mini-dados-container">
              <div v-for="(num, idx) in carasAnimadas" :key="idx" class="dado-mini animando-dado" :class="'dado-d'+(tiradaActual?.caras || 20)">
                {{ num }}
              </div>
            </div>
          </div>

          <transition-group name="fade-roll" tag="div" class="mini-historial-lista">
            <div v-for="item in historial" :key="item.id" class="tirada-item" :class="{'critico-ui': item.critico, 'pifia-ui': item.pifia}">
              <div class="tirada-info">
                <span class="tirada-tit">{{ item.titulo }}</span>
                <span class="tirada-detalles">d{{ item.caras }}: {{ item.resultadosStr }} | Bono: {{ item.bono >= 0 ? '+' : '' }}{{ item.bono }}</span>
              </div>
              <div class="tirada-total">{{ item.total }}</div>
            </div>
          </transition-group>
        </div>
      </div>

    </div>
  </Transition>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@700&family=Inter:wght@400;600;800&display=swap');

/* RAÍZ Y OVERLAY */
.mesa-root { z-index: 9999; }
.mesa-root.is-modal { position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; }
.mesa-root.is-mini { position: fixed; bottom: 20px; right: 20px; }
.overlay-bg { position: absolute; inset: 0; background: rgba(5, 5, 5, 0.85); backdrop-filter: blur(8px); }

/* CONTROLES GLOBALES EXPANDIDO */
.btn-accion { position: absolute; top: 15px; width: 35px; height: 35px; border-radius: 50%; font-size: 1.2rem; cursor: pointer; display: flex; align-items: center; justify-content: center; z-index: 10; transition: 0.2s; }
.btn-cerrar { right: 20px; background: rgba(239, 68, 68, 0.2); color: #fca5a5; border: 1px solid #ef4444; }
.btn-cerrar:hover { background: #ef4444; color: white; transform: scale(1.1); }
.btn-minimizar { right: 65px; background: rgba(59, 130, 246, 0.2); color: #93c5fd; border: 1px solid #3b82f6; }
.btn-minimizar:hover { background: #3b82f6; color: white; transform: scale(1.1); }

/* ========================================== */
/* ESTILOS MODO EXPANDIDO                     */
/* ========================================== */
.mesa-contenedor { width: 1000px; max-width: 95vw; height: 600px; max-height: 90vh; background: #0a0a0c; border: 2px solid #3b82f6; border-radius: 12px; display: flex; overflow: hidden; position: relative; box-shadow: 0 20px 50px rgba(0,0,0,0.8), inset 0 0 30px rgba(59,130,246,0.1); }
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
.hist-datos { display: flex; flex-direction: column; font-size: 0.75rem; color: #cbd5e1; font-family: monospace; }
.hist-bono { color: #93c5fd; }
.hist-total { font-family: 'Cinzel', serif; font-size: 2rem; color: #facc15; font-weight: bold; line-height: 1; text-shadow: 0 0 10px rgba(250,204,21,0.3); }
.texto-crit { color: #facc15 !important; } .texto-pif { color: #fca5a5 !important; }

.panel-tirada { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; position: relative; padding: 2rem; background: radial-gradient(circle at center, #1e293b 0%, #0a0a0c 100%); }
.titulo-tirada-actual { position: absolute; top: 40px; font-family: 'Cinzel', serif; font-size: 2.5rem; color: white; text-align: center; text-shadow: 0 5px 15px rgba(0,0,0,0.8); margin: 0; width: 80%; }

.zona-dados { display: flex; flex-wrap: wrap; justify-content: center; gap: 1.5rem; margin-bottom: 2rem; }
.dado-3d { width: 100px; height: 100px; display: flex; align-items: center; justify-content: center; color: white; font-size: 2.5rem; font-family: 'Inter', sans-serif; font-weight: 800; background: linear-gradient(135deg, #2563eb, #1e3a8a); box-shadow: inset 0 0 15px rgba(0,0,0,0.8), 0 10px 20px rgba(0,0,0,0.5); text-shadow: 2px 2px 4px rgba(0,0,0,0.8); }

.zona-resultados { display: flex; flex-direction: column; align-items: center; position: absolute; bottom: 50px; background: rgba(0,0,0,0.6); padding: 1.5rem 3rem; border-radius: 16px; border: 1px solid #334155; backdrop-filter: blur(5px); }
.resultado-matematica { font-family: monospace; font-size: 1.5rem; color: #94a3b8; display: flex; gap: 1rem; align-items: center; margin-bottom: 0.5rem; }
.math-dados { color: white; background: #1e293b; padding: 0.2rem 0.8rem; border-radius: 8px; }
.math-bono { color: #fca5a5; font-weight: bold; }
.resultado-gigante { font-family: 'Cinzel', serif; font-size: 6rem; font-weight: bold; color: #facc15; line-height: 1; text-shadow: 0 0 30px rgba(250,204,21,0.4); }

/* ========================================== */
/* ESTILOS MODO MINI (WIDGET FLOTANTE)        */
/* ========================================== */
.mesa-mini { width: 340px; background: rgba(10, 10, 12, 0.95); backdrop-filter: blur(10px); border: 1px solid #3b82f6; border-radius: 8px; box-shadow: 0 10px 30px rgba(0,0,0,0.8); display: flex; flex-direction: column; overflow: hidden; }
.mini-header { background: #1e3a8a; color: white; font-weight: bold; font-family: 'Cinzel', serif; padding: 0.6rem 1rem; display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #3b82f6; }
.mini-controles button { background: transparent; border: none; color: #93c5fd; cursor: pointer; font-size: 1rem; margin-left: 0.8rem; transition: 0.2s; }
.mini-controles button:hover { color: white; transform: scale(1.2); }
.mini-body { padding: 0.5rem; max-height: 400px; display: flex; flex-direction: column; }

.mini-zona-tirando { display: flex; flex-direction: column; align-items: center; padding: 1rem; background: radial-gradient(circle, #1e293b, transparent); border-bottom: 1px dashed #334155; margin-bottom: 0.5rem; }
.mini-tit-tirando { color: #facc15; font-weight: bold; font-size: 0.9rem; margin-bottom: 0.8rem; text-align: center; }
.mini-dados-container { display: flex; flex-wrap: wrap; justify-content: center; gap: 0.5rem; }

/* Dados en versión Miniatura */
.dado-mini { width: 45px; height: 45px; font-size: 1.2rem; display: flex; align-items: center; justify-content: center; color: white; font-weight: bold; background: linear-gradient(135deg, #2563eb, #1e3a8a); box-shadow: inset 0 0 5px rgba(0,0,0,0.8); }

.mini-historial-lista { display: flex; flex-direction: column; gap: 0.5rem; overflow-y: auto; padding-right: 0.3rem; }
.mini-historial-lista::-webkit-scrollbar { width: 3px; }
.mini-historial-lista::-webkit-scrollbar-thumb { background: #3b82f6; }

.tirada-item { background: #111; border: 1px solid #334155; border-radius: 4px; padding: 0.5rem; display: flex; justify-content: space-between; align-items: center; border-left: 4px solid #475569; }
.tirada-item.critico-ui { border-left-color: #facc15; background: rgba(250, 204, 21, 0.1); }
.tirada-item.pifia-ui { border-left-color: #ef4444; background: rgba(239, 68, 68, 0.1); }
.tirada-info { display: flex; flex-direction: column; }
.tirada-tit { font-weight: bold; color: white; font-size: 0.8rem; }
.tirada-detalles { font-size: 0.65rem; color: #94a3b8; font-family: monospace; margin-top: 0.1rem; }
.tirada-total { font-family: 'Cinzel', serif; font-size: 1.5rem; font-weight: bold; color: #facc15; }

/* FORMAS DE LOS DADOS (Aplican para gigante y mini) */
.dado-d20, .dado-d12, .dado-d8 { clip-path: polygon(50% 0%, 100% 25%, 100% 75%, 50% 100%, 0% 75%, 0% 25%); }
.dado-d6 { border-radius: 8px; }
.dado-d4 { clip-path: polygon(50% 0%, 0% 100%, 100% 100%); align-items: flex-end; padding-bottom: 10%; }

/* ANIMACIONES */
.animando-dado { animation: shake-roll 0.4s infinite linear, color-pulse 0.4s infinite alternate; }
@keyframes shake-roll {
  0% { transform: rotate(0deg) scale(1) translateY(0); }
  25% { transform: rotate(25deg) scale(1.1) translateY(-5px); }
  50% { transform: rotate(0deg) scale(1) translateY(0); }
  75% { transform: rotate(-25deg) scale(1.1) translateY(5px); }
  100% { transform: rotate(0deg) scale(1) translateY(0); }
}
@keyframes color-pulse {
  from { filter: brightness(1); }
  to { filter: brightness(1.5) drop-shadow(0 0 10px #3b82f6); }
}

.fade-mesa-enter-active, .fade-mesa-leave-active { transition: opacity 0.3s ease; }
.fade-mesa-enter-from, .fade-mesa-leave-to { opacity: 0; }
.slide-up-enter-active { transition: all 0.5s cubic-bezier(0.175, 0.885, 0.32, 1.275); }
.slide-up-enter-from { opacity: 0; transform: translateY(50px) scale(0.8); }
.fade-roll-enter-active, .fade-roll-leave-active { transition: all 0.3s ease; }
.fade-roll-enter-from { opacity: 0; transform: translateY(-10px) scale(0.9); }
.fade-roll-leave-to { opacity: 0; transform: translateX(30px); }
</style>