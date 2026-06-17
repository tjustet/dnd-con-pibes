<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute } from 'vue-router'

const props = defineProps({
  tiendaFijaId: { type: String, default: null },
  tiendaTipo: { type: String, default: '' },
  npcEditando: { type: Object, default: null } // NUEVO: Recibe el NPC si estamos editando
})

const emit = defineEmits(['cerrar', 'guardar-npc'])
const supabase = useSupabaseClient()
const route = useRoute()

const modoRapido = ref(true)

const razas = ['Humano', 'Enano', 'Elfo', 'Orco', 'Mediano', 'Gnomo', 'Dracónido']
const trabajosBase = [
  'Herrero', 'Carpintero', 'Sastre', 'Joyero', 'Alfarero', 'Mercader',
  'Alquimista', 'Mago', 'Tabernero', 'Posadero', 'Panadero', 'Carnicero',
  'Veterano', 'Cartógrafo', 'Agente', 'Caballerizo', 'Capitán', 'Clérigo',
  'Erudito', 'Banquero', 'Servidor', 'Escribano', 'Político', 'Guardia', 'Juez', 'Ladrón'
]
const trabajosOrdenados = ref([...trabajosBase])
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
  'Erudito': { principal: 'int', secundaria: 'wis' },
  'Mago': { principal: 'int', secundaria: 'dex' },
  'Clérigo': { principal: 'wis', secundaria: 'con' }
}

const afinidad = {
  'Enano-Herrero': 10, 'Elfo-Herrero': 3, 'Humano-Herrero': 8,
  'Elfo-Alquimista': 10, 'Orco-Alquimista': 1, 'Gnomo-Alquimista': 10,
  'Orco-Guardia': 10, 'Mediano-Guardia': 4
}

const form = ref({
  nombre: '', raza: 'Humano', trabajo: 'Mercader', nivel: 0, alineamiento: 'Neutral', notas: '', tiendaDestino: props.tiendaFijaId || '',
  imagen_url: '', 
  fuerza: 10, destreza: 10, constitucion: 10, inteligencia: 10, sabiduria: 10, carisma: 10, hp_max: 10, clase_armadura: 10, 
  velocidad: 30
})

const tiendasDisponibles = ref([])

const mapearTiendaATrabajo = (tipo) => {
  if (!tipo) return 'Mercader'
  const t = tipo.toLowerCase()
  if (t.includes('herrero') || t.includes('herrería')) return 'Herrero'
  if (t.includes('carpinter')) return 'Carpintero'
  if (t.includes('sastr')) return 'Sastre'
  if (t.includes('joyer')) return 'Joyero'
  if (t.includes('alfar')) return 'Alfarero'
  if (t.includes('mercado general')) return 'Mercader'
  if (t.includes('alquim')) return 'Alquimista'
  if (t.includes('arcana') || t.includes('magia') || t.includes('pergamino')) return 'Mago'
  if (t.includes('biblioteca')) return 'Erudito'
  if (t.includes('adivin') || t.includes('oráculo')) return 'Oráculo'
  if (t.includes('taberna') || t.includes('cervecería') || t.includes('bodega')) return 'Tabernero'
  if (t.includes('posada')) return 'Posadero'
  if (t.includes('panader')) return 'Panadero'
  if (t.includes('carnicer')) return 'Carnicero'
  if (t.includes('aventurero') || t.includes('gremio')) return 'Veterano'
  if (t.includes('suministro')) return 'Mercader'
  if (t.includes('cartóg')) return 'Cartógrafo'
  if (t.includes('recompensa') || t.includes('subasta')) return 'Agente'
  if (t.includes('establo') || t.includes('montura')) return 'Caballerizo'
  if (t.includes('puerto') || t.includes('dársena')) return 'Capitán'
  if (t.includes('templo') || t.includes('monasterio') || t.includes('curandero')) return 'Clérigo'
  if (t.includes('academia')) return 'Erudito'
  if (t.includes('banco')) return 'Banquero'
  if (t.includes('baños')) return 'Servidor'
  if (t.includes('notar') || t.includes('registro')) return 'Escribano'
  if (t.includes('ayuntamiento')) return 'Político'
  if (t.includes('cuartel') || t.includes('guardia') || t.includes('prisión')) return 'Guardia'
  if (t.includes('tribunal')) return 'Juez'
  if (t.includes('negro') || t.includes('ladrón') || t.includes('contrabandista')) return 'Ladrón'
  return 'Mercader'
}

const prepararOpcionesTrabajo = () => {
  let trabajoRecomendado = 'Mercader'
  if (props.tiendaTipo) trabajoRecomendado = mapearTiendaATrabajo(props.tiendaTipo)
  form.value.trabajo = trabajoRecomendado
  trabajosOrdenados.value = [trabajoRecomendado, ...trabajosBase.filter(t => t !== trabajoRecomendado)]
}

const cargarTiendas = async () => {
  if (props.tiendaFijaId) return 
  const { data } = await supabase.from('tiendas_sesion').select('id, nombre_personalizado, tipo')
  if (data) tiendasDisponibles.value = data
}

const nivelMaximo = computed(() => {
  const clave = `${form.value.raza}-${form.value.trabajo}`
  return afinidad[clave] !== undefined ? afinidad[clave] : 5
})

watch([() => form.value.raza, () => form.value.trabajo], () => {
  if (form.value.nivel > nivelMaximo.value) form.value.nivel = nivelMaximo.value
})

const statsGeneradas = computed(() => {
  let base = { str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10 }
  const razaMod = modRaza[form.value.raza]; for (let s in razaMod) base[s] += razaMod[s]
  const trabajoMod = modTrabajo[form.value.trabajo] || { principal: 'str', secundaria: 'dex' }
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
  return { ...base, hpMax: Math.floor(hpMax), ca: 10 + Math.floor((base.dex - 10) / 2) }
})

watch(statsGeneradas, (nuevos) => {
  if (modoRapido.value && !props.npcEditando) {
    form.value.fuerza = nuevos.str; form.value.destreza = nuevos.dex; form.value.constitucion = nuevos.con
    form.value.inteligencia = nuevos.int; form.value.sabiduria = nuevos.wis; form.value.carisma = nuevos.cha
    form.value.hp_max = nuevos.hpMax; form.value.clase_armadura = nuevos.ca
  }
}, { deep: true, immediate: true })

const calcularMod = (val) => { const m = Math.floor((val - 10) / 2); return m >= 0 ? `+${m}` : m }

const procesarYGuardar = async () => {
  if (!form.value.nombre) return alert("El NPC necesita un nombre.")
  
  const npcFinal = {
    tipo: 'npc',
    campaign_id: route.params.id,
    nombre_pj: form.value.nombre,
    raza: form.value.raza,
    clase: form.value.trabajo,
    nivel: form.value.nivel,
    alineamiento: form.value.alineamiento,
    imagen_url: form.value.imagen_url || null,
    fuerza: form.value.fuerza,
    destreza: form.value.destreza,
    constitucion: form.value.constitucion,
    inteligencia: form.value.inteligencia,
    sabiduria: form.value.sabiduria,
    carisma: form.value.carisma,
    hp_max: form.value.hp_max,
    hp_actual: form.value.hp_max, // Asumimos que se cura al guardar
    clase_armadura: form.value.clase_armadura,
    velocidad: parseInt(form.value.velocidad) || 30,
    notas: form.value.notas,
    inventario: props.npcEditando ? props.npcEditando.inventario : []
  }

  // SI HAY UN NPC EDITANDO, ACTUALIZAMOS. SI NO, INSERTAMOS.
  if (props.npcEditando) {
    const { data, error } = await supabase.from('characters').update(npcFinal).eq('id', props.npcEditando.id).select().single()
    if (error) return alert("Error al editar: " + error.message)
    emit('guardar-npc', data)
  } else {
    const { data, error } = await supabase.from('characters').insert(npcFinal).select().single()
    if (error) return alert("Error al guardar: " + error.message)
    
    // Solo vinculamos tienda si es uno nuevo
    if (form.value.tiendaDestino && !props.tiendaFijaId) {
      // Nota: Esta lógica de vinculación externa está, pero en la tienda se maneja por emit.
      await supabase.from('tiendas_sesion').update({ npc_id: data.id }).eq('id', form.value.tiendaDestino)
    }
    emit('guardar-npc', data)
  }
}

onMounted(() => { 
  if (props.npcEditando) {
    modoRapido.value = false // Forzamos vista avanzada para editar todo manual
    form.value = {
      nombre: props.npcEditando.nombre_pj,
      raza: props.npcEditando.raza,
      trabajo: props.npcEditando.clase,
      nivel: props.npcEditando.nivel,
      alineamiento: props.npcEditando.alineamiento,
      notas: props.npcEditando.notas,
      imagen_url: props.npcEditando.imagen_url || '',
      fuerza: props.npcEditando.fuerza, destreza: props.npcEditando.destreza,
      constitucion: props.npcEditando.constitucion, inteligencia: props.npcEditando.inteligencia,
      sabiduria: props.npcEditando.sabiduria, carisma: props.npcEditando.carisma,
      hp_max: props.npcEditando.hp_max, clase_armadura: props.npcEditando.clase_armadura,
      velocidad: props.npcEditando.velocidad || 30
    }
  } else {
    prepararOpcionesTrabajo()
  }
  cargarTiendas() 
})
</script>

<template>
  <div class="modal-dm-overlay" @click.self="emit('cerrar')">
    <div class="modal-dm-sheet form-grande">
      
      <div class="header-modal-creacion">
        <h3>{{ props.npcEditando ? '✏️ Editar Empleado/NPC' : '✨ Crear Personaje Aliado' }}</h3>
        <button v-if="!props.npcEditando" @click="modoRapido = !modoRapido" class="btn-toggle-modo" :class="{'modo-avanzado': !modoRapido}">
          {{ modoRapido ? '⚙️ Pasar a Avanzado' : '✨ Volver a Rápido' }}
        </button>
      </div>
      
      <div class="generador-grid">
        <div class="col-form">
          <label>Nombre del NPC</label>
          <input type="text" v-model="form.nombre" class="input-form" placeholder="Ej: Kaelen Puñohierro" />

          <label>URL de Retrato / Imagen</label>
          <input type="text" v-model="form.imagen_url" class="input-form" placeholder="https://link-de-la-imagen.png" />

          <div class="input-group" v-if="!props.tiendaFijaId && !props.npcEditando">
            <label class="t-dorado">📍 Asignar a Establecimiento</label>
            <select v-model="form.tiendaDestino" class="input-form borde-dorado">
              <option value="">NPC Libre (Sin tienda)</option>
              <option v-for="t in tiendasDisponibles" :key="t.id" :value="t.id">{{ t.nombre_personalizado || t.tipo }}</option>
            </select>
          </div>

          <div class="row-inputs">
            <div class="input-group">
              <label>Trabajo / Clase</label>
              <select v-model="form.trabajo" class="input-form" :disabled="!modoRapido && !props.npcEditando">
                <option v-for="t in trabajosOrdenados" :key="t" :value="t">{{ t }}</option>
              </select>
            </div>
            <div class="input-group">
              <label>Raza</label>
              <select v-model="form.raza" class="input-form" :disabled="!modoRapido && !props.npcEditando">
                <option v-for="r in razas" :key="r" :value="r">{{ r }}</option>
              </select>
            </div>
          </div>

          <div class="row-inputs">
            <div class="input-group">
              <label>Nivel de Experiencia</label>
              <input type="range" v-model.number="form.nivel" min="0" :max="nivelMaximo" class="slider-nivel" :disabled="!modoRapido && !props.npcEditando" />
              <div class="txt-nivel">Nivel: <strong>{{ form.nivel }}</strong></div>
            </div>
            <div class="input-group">
              <label>Alineamiento</label>
              <select v-model="form.alineamiento" class="input-form">
                <option v-for="a in alineamientos" :key="a" :value="a">{{ a }}</option>
              </select>
            </div>
          </div>

          <label>Notas Privadas del DM</label>
          <textarea v-model="form.notas" class="input-form txt-area" placeholder="Notas..."></textarea>
        </div>

        <div class="col-preview">
          <div class="preview-card" v-if="modoRapido && !props.npcEditando">
            <h4>Previsualización</h4>
            <div class="box-retrato-preview">
              <img v-if="form.imagen_url" :src="form.imagen_url" class="retrato-npc-preview" />
              <div v-else class="retrato-fallback">👤</div>
            </div>
            <div class="p-header">
              <div class="row-inputs centrado">
                <div class="p-hp">❤️ HP: {{ form.hp_max }}</div>
                <div class="p-hp escudo">🛡️ CA: {{ form.clase_armadura }}</div>
              </div>
            </div>
            
            <div class="p-stats-grid">
              <div class="p-stat"><label>STR</label><span>{{ form.fuerza }} ({{ calcularMod(form.fuerza) }})</span></div>
              <div class="p-stat"><label>DEX</label><span>{{ form.destreza }} ({{ calcularMod(form.destreza) }})</span></div>
              <div class="p-stat"><label>CON</label><span>{{ form.constitucion }} ({{ calcularMod(form.constitucion) }})</span></div>
              <div class="p-stat"><label>INT</label><span>{{ form.inteligencia }} ({{ calcularMod(form.inteligencia) }})</span></div>
              <div class="p-stat"><label>WIS</label><span>{{ form.sabiduria }} ({{ calcularMod(form.sabiduria) }})</span></div>
              <div class="p-stat"><label>CHA</label><span>{{ form.carisma }} ({{ calcularMod(form.carisma) }})</span></div>
            </div>
          </div>

          <div class="preview-card editando" v-else>
            <h4 class="t-rojo">Edición Avanzada</h4>
            <div class="row-inputs mb-corto mt-1">
              <div class="input-group"><label>HP Máx</label><input type="number" v-model="form.hp_max" class="input-form"/></div>
              <div class="input-group"><label>CA</label><input type="number" v-model="form.clase_armadura" class="input-form"/></div>
              <div class="input-group"><label>Velocidad</label><input type="number" v-model="form.velocidad" class="input-form"/></div>
            </div>

            <label class="mb-corto block mt-1">Estadísticas Principales</label>
            <div class="p-stats-grid manual">
              <div class="input-group mini"><label>STR</label><input type="number" v-model="form.fuerza" class="input-form txt-centro"/></div>
              <div class="input-group mini"><label>DEX</label><input type="number" v-model="form.destreza" class="input-form txt-centro"/></div>
              <div class="input-group mini"><label>CON</label><input type="number" v-model="form.constitucion" class="input-form txt-centro"/></div>
              <div class="input-group mini"><label>INT</label><input type="number" v-model="form.inteligencia" class="input-form txt-centro"/></div>
              <div class="input-group mini"><label>WIS</label><input type="number" v-model="form.sabiduria" class="input-form txt-centro"/></div>
              <div class="input-group mini"><label>CHA</label><input type="number" v-model="form.carisma" class="input-form txt-centro"/></div>
            </div>
          </div>
        </div>
      </div>

      <div class="acciones-modal">
        <button class="btn-cancelar" @click="emit('cerrar')">Cancelar</button>
        <button class="btn-accion-dm dorado" @click="procesarYGuardar">✨ {{ props.npcEditando ? 'Guardar Cambios' : 'Sellar e Invocar' }}</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.form-grande { width: 850px !important; max-width: 95vw; background: #0a0a0c; border: 2px solid #334155; border-radius: 12px; padding: 2rem; }
.header-modal-creacion { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #1e293b; padding-bottom: 0.8rem; margin-bottom: 1.5rem; }
.header-modal-creacion h3 { margin: 0; color: #facc15; font-family: 'Cinzel', serif; font-size: 1.5rem; }
.btn-toggle-modo { background: #1e3a8a; border: 1px solid #3b82f6; color: white; padding: 0.4rem 1rem; border-radius: 6px; font-weight: bold; cursor: pointer; transition: 0.2s; }
.btn-toggle-modo.modo-avanzado { background: #7f1d1d; border-color: #ef4444; }
.generador-grid { display: grid; grid-template-columns: 1fr 340px; gap: 2rem; margin-bottom: 1.5rem; }
.col-form { display: flex; flex-direction: column; gap: 1rem; }
.row-inputs { display: flex; gap: 1rem; width: 100%; }
.centrado { justify-content: center; }
.block { display: block; }
.mb-corto { margin-bottom: 0.5rem; }
.mt-1 { margin-top: 10px; }
.txt-centro { text-align: center; }
.input-group { flex: 1; display: flex; flex-direction: column; gap: 0.3rem; }
.input-group.mini label { font-size: 0.7rem; color: #facc15; text-align: center;}
.input-group label, .col-form > label { color: #94a3b8; font-size: 0.85rem; font-weight: bold; font-family: 'Cinzel', serif; }
.input-form { background: #111; border: 1px solid #334155; color: white; padding: 0.6rem; border-radius: 6px; outline: none; width: 100%; }
.input-form:focus { border-color: #3b82f6; }
.input-form:disabled { opacity: 0.5; cursor: not-allowed; }
.txt-area { resize: vertical; min-height: 80px; }
.slider-nivel { width: 100%; accent-color: #facc15; margin-top: 0.5rem; }
.txt-nivel { color: #cbd5e1; font-size: 0.9rem; margin-top: 0.3rem; }
.t-gris { color: #cbd5e1; }
.txt-gris { color: #94a3b8; }
.t-rojo { color: #ef4444 !important; }
.t-dorado { color: #facc15 !important; }
.borde-dorado { border: 1px solid #b45309; }
.preview-card { background: #050505; border: 2px solid #3b82f6; border-radius: 8px; padding: 1rem; box-shadow: inset 0 0 20px rgba(59,130,246,0.1); height: 100%; display: flex; flex-direction: column; }
.preview-card.editando { border-color: #ef4444; box-shadow: inset 0 0 20px rgba(239,68,68,0.1); }
.preview-card h4 { color: #3b82f6; margin: 0 0 0.5rem 0; font-family: 'Cinzel', serif; text-align: center; border-bottom: 1px solid #1e293b; padding-bottom: 0.5rem; }
.p-header { text-align: center; margin-bottom: 1rem; }
.p-hp { display: inline-block; background: rgba(239, 68, 68, 0.1); color: #fca5a5; padding: 0.3rem 0.8rem; border-radius: 20px; border: 1px solid #7f1d1d; font-weight: bold; font-size: 0.9rem; }
.p-hp.escudo { background: rgba(59, 130, 246, 0.1); color: #93c5fd; border-color: #1e3a8a; }
.p-stats-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.5rem; }
.p-stats-grid.manual { gap: 0.8rem; }
.p-stat { background: #111; border: 1px solid #1e293b; padding: 0.5rem; border-radius: 6px; text-align: center; }
.p-stat label { display: block; color: #facc15; font-size: 0.7rem; font-weight: bold; margin-bottom: 0.2rem; }
.p-stat span { color: white; font-weight: bold; font-size: 1.1rem; }
.btn-cancelar { background: transparent; border: 1px solid #475569; color: #f1f5f9; padding: 0.6rem 1.2rem; border-radius: 6px; cursor: pointer; font-family: 'Cinzel', serif; transition: 0.2s; }
.btn-cancelar:hover { background: rgba(71, 85, 105, 0.3); color: white; }
.box-retrato-preview { width: 100%; height: 110px; display: flex; justify-content: center; align-items: center; margin-bottom: 10px; }
.retrato-npc-preview { width: 90px; height: 90px; object-fit: cover; border-radius: 50%; border: 2px solid #3b82f6; }
.retrato-fallback { font-size: 3.5rem; background: #111; width: 90px; height: 90px; display: flex; justify-content: center; align-items: center; border-radius: 50%; border: 2px dashed #334155; }
</style>