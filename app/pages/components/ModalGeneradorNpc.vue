<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute } from 'vue-router'

const props = defineProps({
  tiendaFijaId: { type: String, default: null },
  tiendaTipo: { type: String, default: '' },
  npcEditando: { type: Object, default: null }
})

const emit = defineEmits(['cerrar', 'guardar-npc'])
const supabase = useSupabaseClient()
const route = useRoute()

const modoRapido = ref(true)
const excepcionLimiteNivel = ref(false)

const trabajosBase = [
  'Herrero', 'Carpintero', 'Sastre', 'Joyero', 'Alfarero', 'Mercader',
  'Alquimista', 'Mago', 'Tabernero', 'Posadero', 'Panadero', 'Carnicero',
  'Veterano', 'Cartógrafo', 'Agente', 'Caballerizo', 'Capitán', 'Clérigo',
  'Erudito', 'Banquero', 'Servidor', 'Escribano', 'Político', 'Guardia', 'Juez', 'Ladrón'
]
const trabajosOrdenados = ref([...trabajosBase])
const alineamientos = ['Leal Bueno', 'Neutral Bueno', 'Caótico Bueno', 'Leal Neutral', 'Neutral', 'Caótico Neutral', 'Leal Malvado', 'Neutral Malvado', 'Caótico Malvado']

// PEGAR AQUÍ EL modRaza QUE TE DÉ LA OTRA IA
const modRaza = {
  'Aarakocra': { str: 0, dex: 2, con: 0, int: 0, wis: 1, cha: 0 },
  'Aasimar': { str: 0, dex: 0, con: 0, int: 0, wis: 1, cha: 2 },
  'Aasimar(Azote)': { str: 0, dex: 0, con: 1, int: 0, wis: 0, cha: 2 },
  'Aasimar(Caído)': { str: 1, dex: 0, con: 0, int: 0, wis: 0, cha: 2 },
  'Aasimar(Protector)': { str: 0, dex: 0, con: 0, int: 0, wis: 1, cha: 2 },
  'Bugbear': { str: 2, dex: 1, con: 0, int: 0, wis: 0, cha: 0 },
  'Cambiante': { str: 0, dex: 1, con: 0, int: 0, wis: 0, cha: 2 },
  'Cambiaformas(Caza Salvaje)': { str: 0, dex: 1, con: 0, int: 0, wis: 2, cha: 0 },
  'Cambiaformas(Diente Largo)': { str: 2, dex: 1, con: 0, int: 0, wis: 0, cha: 0 },
  'Cambiaformas(Paso Veloz)': { str: 0, dex: 2, con: 0, int: 0, wis: 0, cha: 1 },
  'Cambiaformas(Piel Bestial)': { str: 1, dex: 0, con: 2, int: 0, wis: 0, cha: 0 },
  'Centauro': { str: 2, dex: 0, con: 0, int: 0, wis: 1, cha: 0 },
  'Dracónido': { str: 2, dex: 0, con: 0, int: 0, wis: 0, cha: 1 },
  'Dragonborn': { str: 2, dex: 0, con: 0, int: 0, wis: 0, cha: 1 },
  'Dragonborn(Ravenite)': { str: 2, dex: 0, con: 1, int: 0, wis: 0, cha: 0 },
  'Dragonborn(Sangre de Dragón)': { str: 0, dex: 0, con: 0, int: 2, wis: 0, cha: 1 },
  'Elfo(Aereni)': { str: 0, dex: 2, con: 0, int: 1, wis: 0, cha: 0 },
  'Elfo(Alto)': { str: 0, dex: 2, con: 0, int: 1, wis: 0, cha: 0 },
  'Elfo(Bosque)': { str: 0, dex: 2, con: 0, int: 0, wis: 1, cha: 0 },
  'Elfo(Drow)': { str: 0, dex: 2, con: 0, int: 0, wis: 0, cha: 1 },
  'Elfo(Eladrin)': { str: 0, dex: 2, con: 0, int: 1, wis: 0, cha: 0 },
  'Elfo(Marca de Sombra)': { str: 0, dex: 2, con: 0, int: 0, wis: 0, cha: 1 },
  'Elfo(Mar)': { str: 0, dex: 2, con: 1, int: 0, wis: 0, cha: 0 },
  'Elfo(Pálido)': { str: 0, dex: 2, con: 0, int: 0, wis: 1, cha: 0 },
  'Elfo(Shadar-kai)': { str: 0, dex: 2, con: 1, int: 0, wis: 0, cha: 0 },
  'Elfo(Valenar)': { str: 0, dex: 2, con: 0, int: 0, wis: 1, cha: 0 },
  'Enano(Colina)': { str: 0, dex: 0, con: 2, int: 0, wis: 1, cha: 0 },
  'Enano(Duergar)': { str: 1, dex: 0, con: 2, int: 0, wis: 0, cha: 0 },
  'Enano(Marca de Protección)': { str: 0, dex: 0, con: 2, int: 1, wis: 0, cha: 0 },
  'Enano(Montaña)': { str: 2, dex: 0, con: 2, int: 0, wis: 0, cha: 0 },
  'Firbolg': { str: 1, dex: 0, con: 0, int: 0, wis: 2, cha: 0 },
  'Forjado en Guerra': { str: 1, dex: 0, con: 2, int: 0, wis: 0, cha: 0 },
  'Genasi(Agua)': { str: 0, dex: 0, con: 2, int: 0, wis: 1, cha: 0 },
  'Genasi(Aire)': { str: 0, dex: 1, con: 2, int: 0, wis: 0, cha: 0 },
  'Genasi(Fuego)': { str: 0, dex: 0, con: 2, int: 1, wis: 0, cha: 0 },
  'Genasi(Tierra)': { str: 1, dex: 0, con: 2, int: 0, wis: 0, cha: 0 },
  'Gith(Githyanki)': { str: 2, dex: 0, con: 0, int: 1, wis: 0, cha: 0 },
  'Gith(Githzerai)': { str: 0, dex: 0, con: 0, int: 1, wis: 2, cha: 0 },
  'Gnomo(Bosque)': { str: 0, dex: 1, con: 0, int: 2, wis: 0, cha: 0 },
  'Gnomo(Marca de Escritura)': { str: 0, dex: 0, con: 0, int: 2, wis: 0, cha: 1 },
  'Gnomo(Profundo)': { str: 0, dex: 1, con: 0, int: 2, wis: 0, cha: 0 },
  'Gnomo(Roca)': { str: 0, dex: 0, con: 1, int: 2, wis: 0, cha: 0 },
  'Gnomo(Svirfneblin)': { str: 0, dex: 1, con: 0, int: 2, wis: 0, cha: 0 },
  'Goblin': { str: 0, dex: 2, con: 1, int: 0, wis: 0, cha: 0 },
  'Goblin(Dankwood)': { str: 0, dex: 2, con: 0, int: 0, wis: 1, cha: 0 },
  'Goliat': { str: 2, dex: 0, con: 1, int: 0, wis: 0, cha: 0 },
  'Grung': { str: 0, dex: 2, con: 1, int: 0, wis: 0, cha: 0 },
  'Hobgoblin': { str: 0, dex: 0, con: 2, int: 1, wis: 0, cha: 0 },
  'Humano': { str: 1, dex: 1, con: 1, int: 1, wis: 1, cha: 1 },
  'Humano(Marca de Centinela)': { str: 0, dex: 0, con: 2, int: 0, wis: 1, cha: 0 },
  'Humano(Marca de Creación)': { str: 0, dex: 1, con: 0, int: 2, wis: 0, cha: 0 },
  'Humano(Marca de Descubrimiento)': { str: 0, dex: 2, con: 0, int: 1, wis: 0, cha: 0 },
  'Humano(Marca de Manejo)': { str: 0, dex: 2, con: 0, int: 0, wis: 1, cha: 0 },
  'Humano(Marca de Paso)': { str: 0, dex: 2, con: 1, int: 0, wis: 0, cha: 0 },
  'Humano(Variante)': { str: 0, dex: 0, con: 0, int: 0, wis: 0, cha: 0 },
  'Híbrido Simic': { str: 0, dex: 0, con: 2, int: 1, wis: 0, cha: 0 },
  'Kalashtar': { str: 0, dex: 0, con: 0, int: 0, wis: 2, cha: 1 },
  'Kenku': { str: 0, dex: 2, con: 0, int: 0, wis: 1, cha: 0 },
  'Kobold': { str: -2, dex: 2, con: 0, int: 0, wis: 0, cha: 0 },
  'Lagarto': { str: 0, dex: 0, con: 2, int: 0, wis: 1, cha: 0 },
  'Leonin': { str: 1, dex: 0, con: 2, int: 0, wis: 0, cha: 0 },
  'Locathah': { str: 2, dex: 1, con: 0, int: 0, wis: 0, cha: 0 },
  'Loxodon': { str: 0, dex: 0, con: 2, int: 0, wis: 1, cha: 0 },
  'Mediano(Lotusden)': { str: 0, dex: 2, con: 0, int: 0, wis: 1, cha: 0 },
  'Mediano(Marca de Hospitalidad)': { str: 0, dex: 2, con: 0, int: 0, wis: 0, cha: 1 },
  'Mediano(Marca de Sanación)': { str: 0, dex: 2, con: 0, int: 0, wis: 1, cha: 0 },
  'Mediano(Pieligero)': { str: 0, dex: 2, con: 0, int: 0, wis: 0, cha: 1 },
  'Mediano(Robusto)': { str: 0, dex: 2, con: 1, int: 0, wis: 0, cha: 0 },
  'Mediano(Sabio Fantasma)': { str: 0, dex: 2, con: 0, int: 0, wis: 1, cha: 0 },
  'Medioelfo': { str: 0, dex: 1, con: 0, int: 1, wis: 0, cha: 2 },
  'Medioelfo(Acuático)': { str: 1, dex: 0, con: 0, int: 0, wis: 0, cha: 2 },
  'Medioelfo(Alto)': { str: 0, dex: 0, con: 0, int: 1, wis: 0, cha: 2 },
  'Medioelfo(Bosque)': { str: 0, dex: 1, con: 0, int: 0, wis: 0, cha: 2 },
  'Medioelfo(Drow)': { str: 0, dex: 1, con: 0, int: 0, wis: 0, cha: 2 },
  'Medioelfo(Marca de Detección)': { str: 0, dex: 0, con: 0, int: 1, wis: 2, cha: 0 },
  'Medioelfo(Marca de Tormenta)': { str: 0, dex: 1, con: 0, int: 0, wis: 0, cha: 2 },
  'MedioOrco': { str: 2, dex: 0, con: 1, int: 0, wis: 0, cha: 0 },
  'MedioOrco(Marca de Descubrimiento)': { str: 2, dex: 0, con: 0, int: 0, wis: 1, cha: 0 },
  'Minotauro': { str: 2, dex: 0, con: 1, int: 0, wis: 0, cha: 0 },
  'Orco': { str: 2, dex: 0, con: 1, int: 0, wis: 0, cha: 0 },
  'Sátiro': { str: 0, dex: 1, con: 0, int: 0, wis: 0, cha: 2 },
  'Tabaxi': { str: 0, dex: 2, con: 0, int: 0, wis: 0, cha: 1 },
  'Tiefling': { str: 0, dex: 0, con: 0, int: 1, wis: 0, cha: 2 },
  'Tiefling(Asmodeus)': { str: 0, dex: 0, con: 0, int: 1, wis: 0, cha: 2 },
  'Tiefling(Baalzebul)': { str: 0, dex: 0, con: 0, int: 1, wis: 0, cha: 2 },
  'Tiefling(Dispater)': { str: 0, dex: 1, con: 0, int: 0, wis: 0, cha: 2 },
  'Tiefling(Fierna)': { str: 0, dex: 0, con: 0, int: 0, wis: 1, cha: 2 },
  'Tiefling(Glasya)': { str: 0, dex: 1, con: 0, int: 0, wis: 0, cha: 2 },
  'Tiefling(Levistus)': { str: 0, dex: 0, con: 1, int: 0, wis: 0, cha: 2 },
  'Tiefling(Mammon)': { str: 0, dex: 0, con: 0, int: 1, wis: 0, cha: 2 },
  'Tiefling(Mephistopheles)': { str: 0, dex: 0, con: 0, int: 1, wis: 0, cha: 2 },
  'Tiefling(Variante)': { str: 0, dex: 2, con: 0, int: 1, wis: 0, cha: 0 },
  'Tiefling(Zariel)': { str: 1, dex: 0, con: 0, int: 0, wis: 0, cha: 2 },
  'Tortuga': { str: 2, dex: 0, con: 0, int: 0, wis: 1, cha: 0 },
  'Tritón': { str: 1, dex: 0, con: 1, int: 0, wis: 0, cha: 1 },
  'Vedalken': { str: 0, dex: 0, con: 0, int: 2, wis: 1, cha: 0 },
  'Verdan': { str: 0, dex: 0, con: 2, int: 0, wis: 0, cha: 1 },
  'Yuan-Ti de Sangre Pura': { str: 0, dex: 0, con: 0, int: 1, wis: 0, cha: 2 }
};

// PEGAR AQUÍ EL modTrabajo QUE TE DÉ LA OTRA IA
const modTrabajo = {
  'Agente': { principal: 'cha', secundaria: 'int' },
  'Alfarero': { principal: 'dex', secundaria: 'con' },
  'Alquimista': { principal: 'int', secundaria: 'wis' },
  'Banquero': { principal: 'int', secundaria: 'cha' },
  'Caballerizo': { principal: 'wis', secundaria: 'str' },
  'Capitán': { principal: 'cha', secundaria: 'str' },
  'Carnicero': { principal: 'str', secundaria: 'con' },
  'Carpintero': { principal: 'str', secundaria: 'dex' },
  'Cartógrafo': { principal: 'int', secundaria: 'dex' },
  'Clérigo': { principal: 'wis', secundaria: 'cha' },
  'Erudito': { principal: 'int', secundaria: 'wis' },
  'Escribano': { principal: 'int', secundaria: 'dex' },
  'Guardia': { principal: 'str', secundaria: 'con' },
  'Herrero': { principal: 'str', secundaria: 'con' },
  'Joyero': { principal: 'dex', secundaria: 'int' },
  'Juez': { principal: 'int', secundaria: 'wis' },
  'Ladrón': { principal: 'dex', secundaria: 'cha' },
  'Mago': { principal: 'int', secundaria: 'wis' },
  'Mercader': { principal: 'cha', secundaria: 'wis' },
  'Panadero': { principal: 'con', secundaria: 'dex' },
  'Político': { principal: 'cha', secundaria: 'int' },
  'Posadero': { principal: 'cha', secundaria: 'con' },
  'Sastre': { principal: 'dex', secundaria: 'int' },
  'Servidor': { principal: 'dex', secundaria: 'con' },
  'Tabernero': { principal: 'cha', secundaria: 'con' },
  'Veterano': { principal: 'str', secundaria: 'con' }
};

// PEGAR AQUÍ LA afinidad QUE TE DÉ LA OTRA IA
const afinidad = {
  'Aarakocra-Herrero': 2,
  'Aasimar-Clérigo': 10,
  'Aasimar-Juez': 9,
  'Bugbear-Banquero': 2,
  'Bugbear-Erudito': 2,
  'Bugbear-Ladrón': 9,
  'Bugbear-Veterano': 8,
  'Cambiante-Agente': 10,
  'Cambiante-Ladrón': 9,
  'Centauro-Caballerizo': 1,
  'Centauro-Tabernero': 2,
  'Dracónido-Capitán': 9,
  'Dracónido-Veterano': 9,
  'Dragonborn-Capitán': 9,
  'Dragonborn-Veterano': 9,
  'Elfo(Alto)-Erudito': 9,
  'Elfo(Alto)-Mago': 10,
  'Elfo(Bosque)-Caballerizo': 8,
  'Elfo(Bosque)-Cartógrafo': 9,
  'Elfo(Drow)-Alfarero': 2,
  'Enano(Colina)-Herrero': 9,
  'Enano(Duergar)-Herrero': 9,
  'Enano(Marca de Protección)-Banquero': 8,
  'Enano(Marca de Protección)-Guardia': 9,
  'Enano(Montaña)-Herrero': 10,
  'Enano(Montaña)-Joyero': 9,
  'Enano(Montaña)-Veterano': 9,
  'Firbolg-Banquero': 1,
  'Firbolg-Carpintero': 9,
  'Firbolg-Político': 2,
  'Forjado en Guerra-Guardia': 10,
  'Forjado en Guerra-Veterano': 10,
  'Genasi(Fuego)-Alquimista': 9,
  'Genasi(Fuego)-Herrero': 9,
  'Gith(Githyanki)-Erudito': 2,
  'Gith(Githyanki)-Veterano': 8,
  'Gnomo(Marca de Escritura)-Cartógrafo': 9,
  'Gnomo(Marca de Escritura)-Escribano': 10,
  'Gnomo(Profundo)-Joyero:': 9,
  'Gnomo(Roca)-Alquimista': 10,
  'Gnomo(Roca)-Joyero': 10,
  'Goblin-Agente': 8,
  'Goblin-Banquero': 2,
  'Goblin-Juez': 1,
  'Goblin-Ladrón': 10,
  'Goblin-Político': 2,
  'Goliat-Escribano': 2,
  'Goliat-Guardia': 9,
  'Goliat-Joyero': 2,
  'Goliat-Sastre': 1,
  'Goliat-Veterano': 10,
  'Grung-Tabernero': 1,
  'Hobgoblin-Capitán': 10,
  'Hobgoblin-Guardia': 9,
  'Hobgoblin-Veterano': 9,
  'Humano(Marca de Creación)-Alfarero': 9,
  'Humano(Marca de Creación)-Herrero': 10,
  'Kenku-Escribano': 10,
  'Kenku-Juez': 1,
  'Kenku-Ladrón': 9,
  'Kenku-Político': 1,
  'Kobold-Banquero': 2,
  'Kobold-Capitán': 2,
  'Kobold-Juez': 2,
  'Kobold-Ladrón': 8,
  'Lagarto-Banquero': 1,
  'Lagarto-Carnicero': 9,
  'Lagarto-Político': 1,
  'Lagarto-Tabernero': 2,
  'Locathah-Herrero': 1,
  'Locathah-Panadero': 2,
  'Loxodon-Clérigo': 8,
  'Mediano(Marca de Hospitalidad)-Posadero': 10,
  'Mediano(Marca de Hospitalidad)-Tabernero': 10,
  'Mediano(Marca de Sanación)-Clérigo': 9,
  'Mediano(Pieligero)-Panadero': 10,
  'Mediano(Pieligero)-Posadero': 9,
  'Mediano(Pieligero)-Tabernero': 10,
  'Mediano(Robusto)-Panadero': 9,
  'MedioOrco-Carnicero': 8,
  'MedioOrco-Escribano': 2,
  'MedioOrco-Guardia': 9,
  'MedioOrco-Joyero': 2,
  'MedioOrco-Sastre': 2,
  'MedioOrco-Veterano': 10,
  'Minotauro-Joyero': 2,
  'Minotauro-Juez': 2,
  'Minotauro-Sastre': 2,
  'Orco-Banquero': 2,
  'Orco-Erudito': 1,
  'Orco-Juez': 1,
  'Orco-Mago': 1,
  'Orco-Político': 2,
  'Tabaxi-Agente': 8,
  'Tabaxi-Ladrón': 9,
  'Tabaxi-Mercader': 8,
  'Tiefling-Agente': 9,
  'Tiefling-Ladrón': 8,
  'Tiefling-Político': 8,
  'Tortuga-Mago': 3,
  'Tritón-Capitán': 8,
  'Vedalken-Alquimista': 9,
  'Vedalken-Erudito': 9,
  'Yuan-Ti de Sangre Pura-Agente': 10,
  'Yuan-Ti de Sangre Pura-Político': 9
};

const form = ref({
  nombre: '', raza: 'Humano', trabajo: 'Mercader', nivel: 0, alineamiento: 'Neutral', notas: '', tiendaDestino: props.tiendaFijaId || '',
  imagen_url: '', 
  fuerza: 10, destreza: 10, constitucion: 10, inteligencia: 10, sabiduria: 10, carisma: 10, hp_max: 10, clase_armadura: 10, 
  velocidad: 30
})

const tiendasDisponibles = ref([])

// --- NUEVA LÓGICA: SEPARAR RAZAS RECOMENDADAS ---
const opcionesRaza = computed(() => {
  const trabajoAct = form.value.trabajo
  let recomendadas = []
  let otras = []

  for (const raza in modRaza) {
    const clave = `${raza}-${trabajoAct}`
    const maxNivel = afinidad[clave] !== undefined ? afinidad[clave] : 5
    if (maxNivel > 5) recomendadas.push(raza)
    else otras.push(raza)
  }

  // Las ordenamos alfabéticamente para que queden prolijas
  return { recomendadas: recomendadas.sort(), otras: otras.sort() }
})
// --------------------------------------------------

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
  if (excepcionLimiteNivel.value) return 10
  const clave = `${form.value.raza}-${form.value.trabajo}`
  return afinidad[clave] !== undefined ? afinidad[clave] : 5
})

watch([() => form.value.raza, () => form.value.trabajo, excepcionLimiteNivel], () => {
  if (form.value.nivel > nivelMaximo.value) form.value.nivel = nivelMaximo.value
})

const statsGeneradas = computed(() => {
  let base = { str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10 }
  const razaMod = modRaza[form.value.raza] || { str: 0, dex: 0, con: 0, int: 0, wis: 0, cha: 0 } 
  for (let s in razaMod) base[s] += razaMod[s]
  
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
  
  // SOLUCIÓN: Validamos que la ID de la ruta no sea la palabra "nuevo" antes de mandarla a Supabase
  const idCampanaValido = (route.params.id && route.params.id !== 'nuevo') ? route.params.id : null

  const npcFinal = {
    tipo: 'npc',
    campaign_id: idCampanaValido,
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
    hp_actual: form.value.hp_max, 
    clase_armadura: form.value.clase_armadura,
    velocidad: parseInt(form.value.velocidad) || 30,
    notas: form.value.notas,
    inventario: props.npcEditando ? props.npcEditando.inventario : []
  }

  if (props.npcEditando) {
    const { data, error } = await supabase.from('characters').update(npcFinal).eq('id', props.npcEditando.id).select().single()
    if (error) return alert("Error al editar: " + error.message)
    emit('guardar-npc', data)
  } else {
    const { data, error } = await supabase.from('characters').insert(npcFinal).select().single()
    if (error) return alert("Error al guardar: " + error.message)
    
    if (form.value.tiendaDestino && !props.tiendaFijaId) {
      await supabase.from('tiendas_sesion').update({ npc_id: data.id }).eq('id', form.value.tiendaDestino)
    }
    emit('guardar-npc', data)
  }
}

onMounted(() => { 
  if (props.npcEditando) {
    modoRapido.value = false 
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
    const clave = `${props.npcEditando.raza}-${props.npcEditando.clase}`
    const maxTeorico = afinidad[clave] !== undefined ? afinidad[clave] : 5
    if (props.npcEditando.nivel > maxTeorico) excepcionLimiteNivel.value = true

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
        <h3>{{ props.npcEditando ? '✏️ Editando Personaje' : '✨ Crear Personaje Aliado' }}</h3>
        
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
                <optgroup v-if="opcionesRaza.recomendadas.length > 0" label="🌟 Destacados en este oficio">
                  <option v-for="r in opcionesRaza.recomendadas" :key="r" :value="r">{{ r }}</option>
                </optgroup>
                
                <optgroup label="Resto de Razas">
                  <option v-for="r in opcionesRaza.otras" :key="r" :value="r">{{ r }}</option>
                </optgroup>
              </select>
            </div>
          </div>

          <div class="row-inputs">
            <div class="input-group">
              <div class="flex-between mb-corto">
                <label>Nivel de Experiencia</label>
                <label class="toggle-excepcion" title="Permite ignorar el límite de raza/clase">
                  <input type="checkbox" v-model="excepcionLimiteNivel" :disabled="!modoRapido && !props.npcEditando" />
                  <span>🌟 Excepción</span>
                </label>
              </div>
              <input type="range" v-model.number="form.nivel" min="0" :max="nivelMaximo" class="slider-nivel" :disabled="!modoRapido && !props.npcEditando" />
              <div class="txt-nivel">
                Nivel: <strong>{{ form.nivel }}</strong> 
                <span class="txt-gris txt-chico" v-if="excepcionLimiteNivel">(Sin límite racial)</span>
                <span class="txt-gris txt-chico" v-else>(Máx: {{ nivelMaximo }})</span>
              </div>
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
            <h4 class="t-rojo">Control Estadístico de Ficha</h4>
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
        <button class="btn-cancelar" @click="emit('cerrar')">{{ props.npcEditando ? 'Cancelar Cambios' : 'Descartar' }}</button>
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

optgroup { background: #111; color: #facc15; font-family: 'Cinzel', serif; font-weight: bold; font-style: normal; }
optgroup option { color: white; font-family: 'Inter', sans-serif; font-weight: normal; }

.flex-between { display: flex; justify-content: space-between; align-items: center; }
.toggle-excepcion { display: flex; align-items: center; gap: 5px; cursor: pointer; background: rgba(245, 158, 11, 0.1); padding: 2px 8px; border-radius: 12px; border: 1px solid #b45309; transition: 0.2s; }
.toggle-excepcion:hover { background: rgba(245, 158, 11, 0.2); }
.toggle-excepcion input { accent-color: #facc15; cursor: pointer; }
.toggle-excepcion span { font-size: 0.7rem; color: #facc15; font-weight: bold; }
.txt-chico { font-size: 0.75rem; }

.slider-nivel { width: 100%; accent-color: #facc15; margin-top: 0.2rem; }
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