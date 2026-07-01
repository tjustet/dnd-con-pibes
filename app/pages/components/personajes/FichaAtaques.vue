<script setup>
import { ref, computed } from 'vue'
const props = defineProps({ pj: Object, modoEdicion: Boolean, todosLosEfectos: Array })
const emit = defineEmits(['lanzarDado'])

const filtroAtaques = ref('')
const ataquesFiltrados = computed(() => {
  if (!filtroAtaques.value) return props.pj.ataques
  const f = filtroAtaques.value.toLowerCase()
  return props.pj.ataques.filter(a => a.nombre.toLowerCase().includes(f) || a.desc.toLowerCase().includes(f))
})

const agregarAtaque = () => props.pj.ataques.push({ nombre: '', bono: 0, cant_dados: 1, tipo_dado: 8, bono_dano: 0, rango: '', desc: '', tipo_ataque: 'melee', nivel: 0, es_nuevo: true })
const borrarAtaque = (index) => props.pj.ataques.splice(index, 1)

const tirarHit = (atk) => emit('lanzarDado', { titulo: `Ataque: ${atk.nombre}`, cant: 1, caras: 20, bono: atk.bono })
const tirarDano = (atk) => emit('lanzarDado', { titulo: `Daño: ${atk.nombre}`, cant: atk.cant_dados || 1, caras: atk.tipo_dado || 8, bono: atk.bono_dano, efecto: atk.efecto_aplicado })

// Directiva local: hace que el textarea crezca automáticamente según su contenido
const vAutoGrow = {
  mounted(el) {
    const ajustar = () => { el.style.height = 'auto'; el.style.height = el.scrollHeight + 'px' }
    el.style.overflow = 'hidden'
    ajustar()
    el.addEventListener('input', ajustar)
    el._ajustarAltura = ajustar
  },
  updated(el) {
    // Por si el valor cambia por fuera del input (ej. al cargar datos)
    if (el._ajustarAltura) el._ajustarAltura()
  }
}
</script>

<template>
  <div class="panel-oscuro flex-col">
    <div class="header-seccion-busqueda">
      <h3 class="titulo-dorado">ATAQUES Y CONJUROS</h3>
      <div class="contenedor-filtro"><input v-model="filtroAtaques" placeholder="Buscar..." class="input-buscar-interno" /></div>
      <button v-if="modoEdicion" @click="agregarAtaque" class="btn-add">+ Añadir</button>
    </div>
    <div class="lista-ataques">
      <div v-for="(atk, idx) in ataquesFiltrados" :key="idx" class="bloque-ataque relativo" :class="{'bloque-interactivo': !modoEdicion && pj.tipo === 'pj'}">
        <div class="atk-head">
          <h4>
            <span class="atk-icono">{{ atk.tipo_ataque === 'magia' ? '🪄' : (atk.tipo_ataque === 'rango' ? '🏹' : '⚔️') }}</span>
            <span v-if="atk.nivel > 0" class="atk-badge-nivel">Nvl {{ atk.nivel }}</span>
            <span v-if="atk.efecto_aplicado" class="atk-badge-efecto" style="margin-left: 10px;">{{ atk.efecto_aplicado.icono }} {{ atk.efecto_aplicado.nombre }}</span>
          </h4>
        </div>
        <button v-if="modoEdicion" @click="borrarAtaque(idx)" class="btn-borrar-absoluto">Borrar</button>
        <div class="ataque-stats pr-borrar">
          <div class="atk-campo nom"><label>NOMBRE</label><input v-if="modoEdicion" v-model="atk.nombre"/><span v-else class="texto-bold texto-wrap">{{ atk.nombre || '-' }}</span></div>
          <div class="atk-campo"><label>BONO ATQ.</label><input v-if="modoEdicion" type="number" v-model="atk.bono" class="input-min w-30" /><span v-else class="badge-atq">{{ (atk.bono >= 0 ? '+' : '') }}{{ atk.bono || 0 }}</span></div>
          <div class="atk-campo"><label>DAÑO</label>
            <div v-if="modoEdicion" class="dano-inputs">
              <input type="number" v-model="atk.cant_dados" class="input-min w-30" /><span>d</span>
              <select v-model="atk.tipo_dado" class="input-min select-dado"><option value="4">4</option><option value="6">6</option><option value="8">8</option><option value="10">10</option><option value="12">12</option><option value="20">20</option></select>
              <span>+</span><input type="number" v-model="atk.bono_dano" class="input-min w-30" />
            </div>
            <div v-else class="vista-dano-fijo"><span class="badge-dano">{{ atk.cant_dados || 1 }}d{{ atk.tipo_dado || 8 }} {{ (atk.bono_dano >= 0 ? '+' : '') }}{{ atk.bono_dano || 0 }}</span></div>
          </div>
          <div class="atk-inputs-extra" v-if="modoEdicion">
            <select v-model="atk.tipo_ataque" class="input-base short"><option value="melee">⚔️ C. a Cuerpo</option><option value="rango">🏹 Distancia</option><option value="magia">🪄 Magia</option></select>
            <input type="number" v-model="atk.nivel" placeholder="Nvl" class="input-base short" />
            <select v-model="atk.efecto_aplicado" class="input-base short" style="margin-left: 10px;">
              <option :value="null">Sin efecto extra</option>
              <option v-for="ef in todosLosEfectos" :key="ef.id" :value="ef">{{ ef.icono }} Aplica {{ ef.nombre }}</option>
            </select>
          </div>
        </div>
        <div class="ataque-desc">
          <label>DESCRIPCIÓN</label>
          <textarea v-if="modoEdicion" v-model="atk.desc" v-auto-grow rows="2"></textarea>
          <p v-else class="texto-wrap">{{ atk.desc || 'Sin descripción.' }}</p>
        </div>
        <div v-if="!modoEdicion && pj.tipo === 'pj'" class="overlay-ataque">
          <button @click="tirarHit(atk)" class="btn-tactico hit">🎯 Ataque</button>
          <button @click="tirarDano(atk)" class="btn-tactico dmg">🩸 Daño</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.lista-ataques {
  max-height: 650px;
  overflow-y: auto;
  padding-right: 10px;
  margin-top: 15px;
  resize: vertical;
  min-height: 300px;
}

.bloque-ataque {
  padding: 20px;
  margin-bottom: 15px;
  min-height: 12rem;
  overflow: visible;
  flex-shrink: 0;              /* 👈 clave: evita que la tarjeta se "aplaste" */
  display: flex;
  flex-direction: column;
  justify-content: flex-start;
}

.ataque-desc textarea {
  min-height: 2.4rem;
  resize: none;
}

.lista-ataques::-webkit-scrollbar {
  width: 8px;
}
.lista-ataques::-webkit-scrollbar-track {
  background: rgba(0, 0, 0, 0.2);
  border-radius: 4px;
}
.lista-ataques::-webkit-scrollbar-thumb {
  background: #cba153;
  border-radius: 4px;
}
</style>