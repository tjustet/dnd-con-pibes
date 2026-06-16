<script setup>
import { ref, computed, watch, onMounted } from 'vue'

const props = defineProps({
  // Si le pasamos un ID de tienda, se bloquea ahí. Si no, muestra el selector.
  tiendaFijaId: {
    type: String,
    default: null
  }
})

const emit = defineEmits(['cerrar', 'guardar-npc'])
const supabase = useSupabaseClient()

// --- DICCIONARIOS Y MODIFICADORES ---
const razas = ['Humano', 'Enano', 'Elfo', 'Orco', 'Mediano', 'Gnomo', 'Dracónido']
const trabajos = ['Herrero', 'Alquimista', 'Mercader', 'Tabernero', 'Guardia', 'Ladrón', 'Erudito']
const alineamientos = ['Leal Bueno', 'Neutral Bueno', 'Caótico Bueno', 'Leal Neutral', 'Neutral', 'Caótico Neutral', 'Leal Malvado', 'Neutral Malvado', 'Caótico Malvado']

const modRaza = {
  'Humano': { str: 1, dex: 1, con: 1, int: 1, wis: 1, cha: 1 },
  'Enano': { str: 2, dex: -1, con: 2, int: 0, wis: 1, cha: -1 },
  'Elfo': { str: -1, dex: 2, con: -1, int: 1, wis: 1, cha: 1 },
  'Orco': { str: 3, dex: 0, con: 2, int: -2, wis: -1, cha: -2 },
  'Mediano': { str: -2, dex: 2, con: 0, int: 0, wis: 1, cha: 2 },
  'Gnomo': { str: -1, dex: 1, con: 0, int: 2, wis: 0, cha: 1 },
  'Dracónido': { str: 2, dex: 0, con: 1, int: 0, wis: 0, cha: 1 }
}

const modTrabajo = {
  'Herrero': { principal: 'str', secundaria: 'con' },
  'Alquimista': { principal: 'int', secundaria: 'dex' },
  'Mercader': { principal: 'cha', secundaria: 'wis' },
  'Tabernero': { principal: 'cha', secundaria: 'con' },
  'Guardia': { principal: 'str', secundaria: 'dex' },
  'Ladrón': { principal: 'dex', secundaria: 'cha' },
  'Erudito': { principal: 'int', secundaria: 'wis' }
}

const afinidad = {
  'Enano-Herrero': 10, 'Elfo-Herrero': 3, 'Humano-Herrero': 8,
  'Elfo-Alquimista': 10, 'Orco-Alquimista': 1, 'Gnomo-Alquimista': 10,
  'Orco-Guardia': 10, 'Mediano-Guardia': 4
}

// --- ESTADOS ---
const form = ref({
  nombre: '', raza: 'Humano', trabajo: 'Mercader', nivel: 0, alineamiento: 'Neutral', notas: '', tiendaDestino: props.tiendaFijaId || ''
})
const tiendasDisponibles = ref([])

// --- CARGAR TIENDAS DE SUPABASE ---
const cargarTiendas = async () => {
  if (props.tiendaFijaId) return // Si ya estamos en una tienda, no hace falta cargar la lista
  const { data, error } = await supabase.from('tiendas').select('id, nombre, tipo')
  if (data) tiendasDisponibles.value = data
}

// --- LÓGICA DE CÁLCULO ---
const nivelMaximo = computed(() => {
  const clave = `${form.value.raza}-${form.value.trabajo}`
  return afinidad[clave] !== undefined ? afinidad[clave] : 5
})

watch([() => form.value.raza, () => form.value.trabajo], () => {
  if (form.value.nivel > nivelMaximo.value) form.value.nivel = nivelMaximo.value
})

const statsGeneradas = computed(() => {
  let base = { str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10 }
  const razaMod = modRaza[form.value.raza]
  for (let stat in razaMod) base[stat] += razaMod[stat]

  const trabajoMod = modTrabajo[form.value.trabajo]
  const nivel = form.value.nivel

  if (nivel > 0) {
    base[trabajoMod.principal] += Math.floor(nivel * 1.5)
    base[trabajoMod.secundaria] += nivel
    if (nivel >= 5) { base.wis += 2; base.cha += 1 }
    if (nivel >= 8) { base.wis += 2; base.cha += 2 }
  }

  const modCon = Math.floor((base.con - 10) / 2)
  const hpBaseTrabajo = form.value.trabajo === 'Guardia' || form.value.trabajo === 'Herrero' ? 10 : 6
  const hpMax = hpBaseTrabajo + (Math.max(1, hpBaseTrabajo / 2 + modCon) * Math.max(1, nivel))

  return { ...base, hpMax: Math.floor(hpMax) }
})

const calcularMod = (val) => {
  const mod = Math.floor((val - 10) / 2)
  return mod >= 0 ? `+${mod}` : mod
}

const procesarYGuardar = async () => {
  if (!form.value.nombre) return alert("El NPC necesita un nombre.")
  
  const npcFinal = {
    tipo: 'npc',
    nombre_pj: form.value.nombre,
    raza: form.value.raza,
    clase: form.value.trabajo,
    nivel: form.value.nivel,
    alineamiento: form.value.alineamiento,
    fuerza: statsGeneradas.value.str,
    destreza: statsGeneradas.value.dex,
    constitucion: statsGeneradas.value.con,
    inteligencia: statsGeneradas.value.int,
    sabiduria: statsGeneradas.value.wis,
    carisma: statsGeneradas.value.cha,
    hp_max: statsGeneradas.value.hpMax,
    hp_actual: statsGeneradas.value.hpMax,
    notas: form.value.notas,
    inventario: [],
    // Guardamos la relación si se seleccionó una tienda
    tienda_id: form.value.tiendaDestino || null
  }

  // Guardado directo en Supabase
  const { data, error } = await supabase.from('characters').insert(npcFinal).select().single()
  if (error) {
    alert("Error al guardar: " + error.message)
    return
  }

  emit('guardar-npc', data) // Devolvemos el NPC ya creado con su ID real
}

onMounted(() => { cargarTiendas() })
</script>

<template>
  <div class="modal-dm-overlay" @click.self="emit('cerrar')">
    <div class="modal-dm-sheet form-grande">
      <h3>Creación Inteligente de NPC</h3>
      
      <div class="generador-grid">
        <div class="col-form">
          <label>Nombre del NPC</label>
          <input type="text" v-model="form.nombre" class="input-form" placeholder="Ej: Kaelen Puñohierro" />

          <div class="input-group" v-if="!props.tiendaFijaId">
            <label class="t-dorado">📍 Asignar a Establecimiento (Opcional)</label>
            <select v-model="form.tiendaDestino" class="input-form borde-dorado">
              <option value="">NPC Libre (Sin tienda)</option>
              <option v-for="t in tiendasDisponibles" :key="t.id" :value="t.id">{{ t.nombre }} ({{ t.tipo }})</option>
            </select>
          </div>

          <div class="row-inputs">
            <div class="input-group">
              <label>Trabajo / Clase</label>
              <select v-model="form.trabajo" class="input-form">
                <option v-for="t in trabajos" :key="t" :value="t">{{ t }}</option>
              </select>
            </div>
            <div class="input-group">
              <label>Raza</label>
              <select v-model="form.raza" class="input-form">
                <option v-for="r in razas" :key="r" :value="r">{{ r }}</option>
              </select>
            </div>
          </div>

          <div class="row-inputs">
            <div class="input-group">
              <label>Nivel de Experiencia (0 a {{ nivelMaximo }})</label>
              <input type="range" v-model.number="form.nivel" min="0" :max="nivelMaximo" class="slider-nivel" />
              <div class="txt-nivel">Nivel actual: <strong>{{ form.nivel }}</strong> <span class="txt-chico t-gris" v-if="form.nivel === nivelMaximo">(Máx para esta raza)</span></div>
            </div>
            <div class="input-group">
              <label>Alineamiento</label>
              <select v-model="form.alineamiento" class="input-form">
                <option v-for="a in alineamientos" :key="a" :value="a">{{ a }}</option>
              </select>
            </div>
          </div>

          <label>Notas Privadas del DM</label>
          <textarea v-model="form.notas" class="input-form txt-area" placeholder="Ej: Debe dinero a la mafia local..."></textarea>
        </div>

        <div class="col-preview">
          <div class="preview-card">
            <h4>Previsualización de Ficha</h4>
            <div class="p-header">
              <span class="p-name">{{ form.nombre || 'NPC Sin Nombre' }}</span>
              <span class="p-sub">{{ form.raza }} {{ form.trabajo }} - Nvl {{ form.nivel }}</span>
              <div class="p-hp">❤️ HP: {{ statsGeneradas.hpMax }}</div>
            </div>
            
            <div class="p-stats-grid">
              <div class="p-stat"><label>STR</label><span>{{ statsGeneradas.str }} ({{ calcularMod(statsGeneradas.str) }})</span></div>
              <div class="p-stat"><label>DEX</label><span>{{ statsGeneradas.dex }} ({{ calcularMod(statsGeneradas.dex) }})</span></div>
              <div class="p-stat"><label>CON</label><span>{{ statsGeneradas.con }} ({{ calcularMod(statsGeneradas.con) }})</span></div>
              <div class="p-stat"><label>INT</label><span>{{ statsGeneradas.int }} ({{ calcularMod(statsGeneradas.int) }})</span></div>
              <div class="p-stat"><label>WIS</label><span>{{ statsGeneradas.wis }} ({{ calcularMod(statsGeneradas.wis) }})</span></div>
              <div class="p-stat"><label>CHA</label><span>{{ statsGeneradas.cha }} ({{ calcularMod(statsGeneradas.cha) }})</span></div>
            </div>
          </div>
        </div>
      </div>

      <div class="acciones-modal">
        <button class="btn-cancelar" @click="emit('cerrar')">Cancelar</button>
        <button class="btn-accion-dm dorado" @click="procesarYGuardar">✨ Sellar e Invocar NPC</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.form-grande { width: 850px !important; max-width: 95vw; }
.generador-grid { display: grid; grid-template-columns: 1fr 300px; gap: 2rem; margin-bottom: 1.5rem; }
.col-form { display: flex; flex-direction: column; gap: 1rem; }
.row-inputs { display: flex; gap: 1rem; }
.input-group { flex: 1; display: flex; flex-direction: column; gap: 0.3rem; }
.input-group label, .col-form > label { color: #94a3b8; font-size: 0.85rem; font-weight: bold; font-family: 'Cinzel', serif; }
.input-form { background: #111; border: 1px solid #334155; color: white; padding: 0.6rem; border-radius: 6px; outline: none; width: 100%; }
.input-form:focus { border-color: #3b82f6; }
.txt-area { resize: vertical; min-height: 80px; }
.slider-nivel { width: 100%; accent-color: #facc15; margin-top: 0.5rem; }
.txt-nivel { color: #cbd5e1; font-size: 0.9rem; margin-top: 0.3rem; }
.t-gris { color: #64748b; }
.t-dorado { color: #facc15 !important; }
.borde-dorado { border: 1px solid #b45309; }

.preview-card { background: #0a0a0c; border: 2px solid #3b82f6; border-radius: 8px; padding: 1rem; box-shadow: inset 0 0 20px rgba(59,130,246,0.1); height: 100%; display: flex; flex-direction: column; }
.preview-card h4 { color: #3b82f6; margin: 0 0 1rem 0; font-family: 'Cinzel', serif; text-align: center; border-bottom: 1px solid #1e293b; padding-bottom: 0.5rem; }
.p-header { text-align: center; margin-bottom: 1.5rem; }
.p-name { display: block; font-size: 1.2rem; color: white; font-weight: bold; font-family: 'Cinzel', serif; }
.p-sub { display: block; color: #94a3b8; font-size: 0.8rem; margin-top: 0.2rem; }
.p-hp { display: inline-block; margin-top: 0.5rem; background: rgba(239, 68, 68, 0.1); color: #fca5a5; padding: 0.3rem 0.8rem; border-radius: 20px; border: 1px solid #7f1d1d; font-weight: bold; }

.p-stats-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.5rem; }
.p-stat { background: #111; border: 1px solid #1e293b; padding: 0.5rem; border-radius: 6px; text-align: center; }
.p-stat label { display: block; color: #facc15; font-size: 0.7rem; font-weight: bold; margin-bottom: 0.2rem; }
.p-stat span { color: white; font-weight: bold; font-size: 1.1rem; }
</style>