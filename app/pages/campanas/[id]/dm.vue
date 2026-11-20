<script setup>
definePageMeta({ middleware: 'director' })
import { ref, computed, onMounted, onUnmounted } from 'vue'

// IMPORTACIONES EXPRESAS DE COMPONENTES
import GestorTiendasDM from '../../../components/dm/GestorTiendasDM.vue' // IMPORTACIÓN CONFIRMADA
import DmTrackerIniciativa from '../../../components/dm/DmTrackerIniciativa.vue'
import DmMesaDados from '../../../components/dm/DmMesaDados.vue'
import DmDrawerDetalles from '../../../components/dm/DmDrawerDetalles.vue'
import NotasDM from '../../../components/NotasDM.vue'

// --- LÓGICA DE TIENDAS Y CARRITOS ---
const modalTiendasAbierto = ref(false)

const { avisar } = useAvisos()
const resolviendo = ref(false)
const pedidos = computed(() => Object.entries(estadoMesa.value.carritos || {})
  .filter(([, pedido]) => pedido.estado === 'pagando'))
async function resolverPedido(pjId, pedido, aprobar) {
  if (resolviendo.value) return
  resolviendo.value = true
  try {
    if (aprobar) {
      const { error } = await supabase.rpc('dnd_vender', { p_campana: campaignId, p_tienda: String(pedido.tienda),
        p_pedido: pjId, p_operacion: pedido.id, p_lineas: [] })
      if (error) throw error
    } else {
      await actualizarCampana(supabase, campaignId, 'mesa_estado', mesa => {
        const actual = mesa?.carritos?.[pjId]
        if (actual?.id !== pedido.id || actual.estado !== 'pagando') throw new Error('El pedido cambió.')
        actual.estado = 'rechazado'
        return mesa
      })
    }
    if (estadoMesa.value.carritos[pjId]?.id === pedido.id)
      estadoMesa.value.carritos[pjId].estado = aprobar ? 'aprobado' : 'rechazado'
    avisar(aprobar ? 'Compra aprobada.' : 'Pedido rechazado.')
  } catch (e) { avisar(e.message, true) }
  finally { resolviendo.value = false }
}

const route = useRoute()
const campaignId = route.params.id
const errorCarga = ref(false)
const router = useRouter()
const supabase = useSupabaseClient()

const cargando = ref(true)
const campana = ref({ nombre: 'Cargando Mesa del DM...' })

// ==========================================
// ESTADO PERSISTENTE Y REALTIME
// ==========================================
const estadoMesa = ref({ pjs: [], npcs: [], enemigos: [], entidadVisible: null, carritos: {} })
const historialCompartido = ref([]) 
let canalMesa = null 
let canalPersonajes = null 

const todosLosPjsDeCampana = ref([])
const npcsDisponibles = ref([])
const enemigosDisponibles = ref([])

const filtroPj = ref('')
const filtroNpc = ref({ nombre: '', dificultad: '' })
const filtroEnemigo = ref({ nombre: '', dificultad: '' })

const personajesActivos = computed(() => estadoMesa.value.pjs.map(id => todosLosPjsDeCampana.value.find(p => p.id === id)).filter(Boolean))
const npcsActivos = computed(() => estadoMesa.value.npcs)
const enemigosActivos = computed(() => estadoMesa.value.enemigos)

const jugadoresIzquierda = computed(() => personajesActivos.value.slice(0, 3))
const jugadoresDerecha = computed(() => personajesActivos.value.slice(3, 5))
const jugadoresSuperiores = computed(() => personajesActivos.value.slice(5))
const todasLasEntidadesActivas = computed(() => [...personajesActivos.value, ...npcsActivos.value, ...enemigosActivos.value])

const drawerAbierto = ref(false)
const drawerLado = ref('left')
const entidadActiva = ref(null)
const tipoEntidadActiva = ref('')
const filtroAtaquesDrawer = ref('')
const tooltipActivo = ref(null) 

const modalAgregarJugadorAbierto = ref(false)
const modalAgregarNpcAbierto = ref(false)
const modalAgregarEnemigoAbierto = ref(false)
const modalIniciativaAbierto = ref(false)

const dadosOcultos = ref(false)
const dmPool = ref([])
const dmBono = ref(0)
const dmTirando = ref(false)
const dmDadosEnMesa = ref([])
const dmResultadoFinal = ref(0)

const combateActivo = ref(false)
const ordenIniciativa = ref([])
const turnoActual = ref(0)
const seleccionIniciativa = ref([])

const calcMod = (val) => Math.floor((val - 10) / 2)
const calcModStr = (val) => { const m = calcMod(val); return m >= 0 ? `+${m}` : `${m}` }

// ------------------------------------------
// PERSISTENCIA DE MESA Y DADOS
// ------------------------------------------
let ultimaMesa = {}
let colaMesa = Promise.resolve()
let montado = true
function guardarMesaDb() {
  const captura = JSON.parse(JSON.stringify(estadoMesa.value))
  delete captura.carritos
  colaMesa = colaMesa.then(async () => {
    const cambios = Object.fromEntries(Object.entries(captura).filter(([k, v]) =>
      JSON.stringify(v) !== JSON.stringify(ultimaMesa[k])))
    if (!Object.keys(cambios).length) return
    await actualizarCampana(supabase, campaignId, 'mesa_estado', previa => ({ ...previa, ...cambios }))
    ultimaMesa = captura
  }).catch(e => avisar('No se guardaron los cambios de la mesa. ' + e.message, true))
  return colaMesa
}
// ------------------------------------------
// LÓGICA DE DADOS
// ------------------------------------------
const agregarDadoDm = (caras) => dmPool.value.push(caras)
const limpiarPoolDm = () => { dmPool.value = []; dmBono.value = 0; dmDadosEnMesa.value = []; dmResultadoFinal.value = 0 }

const tirarPoolDm = (tituloPerso = null) => {
  if (dmTirando.value || !dmPool.value.length) return
  dmTirando.value = true
  dmResultadoFinal.value = 0
  const arrayDeCaras = [...dmPool.value]
  const bonoNum = parseInt(dmBono.value) || 0

  const intervalo = setInterval(() => { dmDadosEnMesa.value = arrayDeCaras.map(c => ({ caras: c, valor: Math.floor(Math.random() * c) + 1 })) }, 100)

  setTimeout(() => {
    clearInterval(intervalo)
    let suma = 0
    dmDadosEnMesa.value = arrayDeCaras.map(c => { const v = Math.floor(Math.random() * c) + 1; suma += v; return { caras: c, valor: v } })
    dmResultadoFinal.value = suma + bonoNum
    dmTirando.value = false

    const nuevaTirada = {
      id: idOperacion(),
      tirador: 'DM',
      titulo: tituloPerso || 'Tirada del DM',
      dadosStr: dmDadosEnMesa.value.map(d => `d${d.caras}[${d.valor}]`).join(', '),
      bono: bonoNum,
      total: dmResultadoFinal.value,
      oculto: dadosOcultos.value,
      targetAsignado: '',
      mostrarAsignador: false
    }

    const nuevoHist = [nuevaTirada, ...historialCompartido.value].slice(0, 30)
    historialCompartido.value = nuevoHist
    anotarTirada(supabase, campaignId, nuevaTirada).catch(e => avisar(e.message, true))
  }, 1200)
}

const tirarDesdeDrawer = (titulo, caras, bono) => {
  limpiarPoolDm()
  if (Array.isArray(caras)) caras.forEach(c => agregarDadoDm(c))
  else agregarDadoDm(caras)
  dmBono.value = bono || 0
  tirarPoolDm(`${entidadActiva.value.nombre_pj}: ${titulo}`)
}

const tirarAtaque = (atk) => tirarDesdeDrawer(`Ataca con ${atk.nombre}`, 20, atk.bono)
const tirarDano = (atk) => { const dados = Array(Math.max(1, Math.min(100, parseInt(atk.cant_dados) || 1))).fill(Number(atk.tipo_dado) || 6); tirarDesdeDrawer(`Daño de ${atk.nombre}`, dados, atk.bono_dano) }
const tirarStat = (nombre, valor) => tirarDesdeDrawer(`Chequeo de ${nombre}`, 20, calcMod(valor))

// ------------------------------------------
// DAÑO Y CURACIÓN
// ------------------------------------------
const aplicarDano = (registro) => { if (registro.targetAsignado) { procesarHp(registro.targetAsignado, -registro.total); registro.mostrarAsignador = false } }
const curarDano = (registro) => { if (registro.targetAsignado) { procesarHp(registro.targetAsignado, registro.total); registro.mostrarAsignador = false } }

const procesarHp = (instanceId, cantidad) => {
  const pj = personajesActivos.value.find(p => p.id === instanceId)
  if (pj) {
    pj.hp_actual = Math.max(0, Math.min(pj.hp_max, pj.hp_actual + cantidad))
    guardarCampoPJ(pj, 'hp_actual')
    return
  }
  const npc = estadoMesa.value.npcs.find(n => n.instance_id === instanceId)
  if (npc) { npc.hp_actual = Math.max(0, Math.min(npc.hp_max, npc.hp_actual + cantidad)); guardarMesaDb(); return }
  
  const en = estadoMesa.value.enemigos.find(e => e.instance_id === instanceId)
  if (en) { en.hp_actual = Math.max(0, Math.min(en.hp_max, en.hp_actual + cantidad)); guardarMesaDb() }
}

async function guardarCampoPJ(pj, campo) {
  const { error } = await supabase.from('characters').update({ [campo]: pj[campo] }).eq('id', pj.id).select('id').single()
  if (error) {
    avisar('No se pudo guardar el cambio del personaje.', true)
    const { data } = await supabase.from('characters').select(campo).eq('id', pj.id).single()
    if (data) pj[campo] = data[campo]
  }
}
const guardarHpYQuitarFoco = (event, entidad, tipo) => {
  entidad.hp_actual = Math.max(0, Math.min(entidad.hp_max, entidad.hp_actual))
  if (tipo === 'pj') {
    guardarCampoPJ(entidad, 'hp_actual')
  } else {
    guardarMesaDb()
  }
  event.target.blur() 
}

const mostrarAJugadores = (entidad) => { estadoMesa.value.entidadVisible = { nombre: entidad.nombre_pj, imagen: entidad.imagen_url || '' }; guardarMesaDb() }
const limpiarVisionJugadores = () => { estadoMesa.value.entidadVisible = null; guardarMesaDb() }

const cargarMesaDM = async () => {
  cargando.value = true
  errorCarga.value = false
  const { data: cData } = await supabase.from('campaigns').select('*').eq('id', route.params.id).single()
  if (!cData) { cargando.value = false; errorCarga.value = true; return }
  if (cData) {
    campana.value = cData
    estadoMesa.value = estadoInicial(cData.mesa_estado)
    ultimaMesa = JSON.parse(JSON.stringify(estadoMesa.value))
    if (cData.historial_dados) historialCompartido.value = cData.historial_dados
  }

  const { data: pData } = await supabase.from('characters').select('*').eq('campaign_id', route.params.id)
  if (!pData) { cargando.value = false; errorCarga.value = true; return }
  if (!montado) return
  if (pData) {
    const parsedData = pData.map(p => ({ ...p, ataques: listaGuardada(p.ataques) }))
    todosLosPjsDeCampana.value = parsedData.filter(p => p.tipo === 'pj' || !p.tipo)
    npcsDisponibles.value = parsedData.filter(p => p.tipo === 'npc')
    enemigosDisponibles.value = parsedData.filter(p => p.tipo === 'enemigo')
  }

  canalMesa = supabase.channel('mesa_compartida_' + campaignId)
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'campaigns', filter: `id=eq.${route.params.id}` }, (payload) => {
      estadoMesa.value.carritos = payload.new.mesa_estado?.carritos || {}
      if (payload.new.historial_dados) historialCompartido.value = payload.new.historial_dados
    }).subscribe()

  canalPersonajes = supabase.channel('personajes_realtime_' + campaignId)
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'characters', filter: `campaign_id=eq.${route.params.id}` }, (payload) => {
      const pjIndex = todosLosPjsDeCampana.value.findIndex(p => p.id === payload.new.id)
      if (pjIndex !== -1) {
        Object.assign(todosLosPjsDeCampana.value[pjIndex], payload.new)
      }
    }).subscribe()

  const { data: efData } = await supabase.from('efectos').select('*').order('nombre')
  if (efData) todosEfectos.value = efData

  cargando.value = false
}

onUnmounted(() => {
  montado = false
  if (canalMesa) supabase.removeChannel(canalMesa)
  if (canalPersonajes) supabase.removeChannel(canalPersonajes)
})

const pjsFiltrados = computed(() => todosLosPjsDeCampana.value.filter(p => p.nombre_pj?.toLowerCase().includes(filtroPj.value.toLowerCase())))
const npcsFiltrados = computed(() => npcsDisponibles.value.filter(n => n.nombre_pj?.toLowerCase().includes(filtroNpc.value.nombre.toLowerCase()) && (filtroNpc.value.dificultad === '' || n.dificultad == filtroNpc.value.dificultad)))
const enemigosFiltrados = computed(() => enemigosDisponibles.value.filter(e => e.nombre_pj?.toLowerCase().includes(filtroEnemigo.value.nombre.toLowerCase()) && (filtroEnemigo.value.dificultad === '' || e.dificultad == filtroEnemigo.value.dificultad)))
const ataquesFiltradosDrawer = computed(() => { if (!entidadActiva.value || !entidadActiva.value.ataques) return []; return entidadActiva.value.ataques.filter(a => a.nombre?.toLowerCase().includes(filtroAtaquesDrawer.value.toLowerCase())) })

const agregarAlTablero = (entidad, tipo) => {
  if (tipo === 'pj' && !estadoMesa.value.pjs.includes(entidad.id)) estadoMesa.value.pjs.push(entidad.id)
  else if (tipo === 'npc') estadoMesa.value.npcs.push({ ...entidad, instance_id: 'npc_' + idOperacion(), base_id: entidad.id })
  else if (tipo === 'enemigo') estadoMesa.value.enemigos.push({ ...entidad, instance_id: 'en_' + idOperacion(), base_id: entidad.id })
  guardarMesaDb(); modalAgregarJugadorAbierto.value = false; modalAgregarNpcAbierto.value = false; modalAgregarEnemigoAbierto.value = false
}
const desvincular = (idUnico, tipo) => {
  if (tipo === 'pj') estadoMesa.value.pjs = estadoMesa.value.pjs.filter(id => id !== idUnico)
  if (tipo === 'npc') estadoMesa.value.npcs = estadoMesa.value.npcs.filter(n => n.instance_id !== idUnico)
  if (tipo === 'enemigo') estadoMesa.value.enemigos = estadoMesa.value.enemigos.filter(e => e.instance_id !== idUnico)
  guardarMesaDb(); if (entidadActiva.value?.id === idUnico || entidadActiva.value?.instance_id === idUnico) drawerAbierto.value = false
}

const abrirDrawer = (entidad, tipo, lado) => { entidadActiva.value = entidad; tipoEntidadActiva.value = tipo; drawerLado.value = lado; filtroAtaquesDrawer.value = ''; drawerAbierto.value = true }
const abrirFichaNuevaPestana = () => { window.open(`/personajes/${entidadActiva.value.base_id || entidadActiva.value.id}`, '_blank') }

const prepararIniciativa = () => { seleccionIniciativa.value = todasLasEntidadesActivas.value.map(e => e.instance_id || e.id); modalIniciativaAbierto.value = true }
const lanzarIniciativaGlobal = () => {
  const combatientes = todasLasEntidadesActivas.value.filter(e => seleccionIniciativa.value.includes(e.instance_id || e.id))
  if (!combatientes.length) return avisar('Seleccioná al menos un combatiente.')
  ordenIniciativa.value = combatientes.map(c => {
    const d20 = Math.floor(Math.random() * 20) + 1; const modDex = calcMod(c.destreza)
    return { unique_id: c.instance_id || c.id, nombre: c.nombre_pj, imagen: c.imagen_url, total: d20 + modDex, hp_actual: c.hp_actual, hp_max: c.hp_max }
  }).sort((a, b) => b.total - a.total)
  turnoActual.value = 0; combateActivo.value = true; modalIniciativaAbierto.value = false
}
const siguienteTurno = () => { turnoActual.value = (turnoActual.value + 1) % ordenIniciativa.value.length }
const terminarCombate = () => { combateActivo.value = false; ordenIniciativa.value = [] }

const todosEfectos = ref([])
const efectoAInsertar = ref(null)

const agregarEfectoManual = (entidad, tipo) => {
  if (!efectoAInsertar.value) return
  if (!entidad.efectos) entidad.efectos = []
  if (!entidad.efectos.some(e => e.id === efectoAInsertar.value.id)) {
    entidad.efectos.push(efectoAInsertar.value)
    if (tipo === 'pj') {
      guardarCampoPJ(entidad, 'efectos')
    } else {
      guardarMesaDb()
    }
  }
  efectoAInsertar.value = null 
}

const quitarEfectoManual = (entidad, tipo, idEfecto) => {
  entidad.efectos = entidad.efectos.filter(e => e.id !== idEfecto)
  if (tipo === 'pj') {
    guardarCampoPJ(entidad, 'efectos')
  } else {
    guardarMesaDb()
  }
}

const aplicarEfectoDesdeHistorial = (registro) => {
  if (!registro.targetAsignado || !registro.efecto_vinculado) return
  const targetId = registro.targetAsignado
  const pj = personajesActivos.value.find(p => p.id === targetId)
  if (pj) { agregarEfectoDesdeObj(pj, 'pj', registro.efecto_vinculado); return }
  const npc = estadoMesa.value.npcs.find(n => n.instance_id === targetId)
  if (npc) { agregarEfectoDesdeObj(npc, 'npc', registro.efecto_vinculado); return }
  const en = estadoMesa.value.enemigos.find(e => e.instance_id === targetId)
  if (en) { agregarEfectoDesdeObj(en, 'enemigo', registro.efecto_vinculado) }
}

const agregarEfectoDesdeObj = (entidad, tipo, objEfecto) => {
  if (!entidad.efectos) entidad.efectos = []
  if (!entidad.efectos.some(e => e.id === objEfecto.id)) {
    entidad.efectos.push(objEfecto)
    if (tipo === 'pj') guardarCampoPJ(entidad, 'efectos')
    else guardarMesaDb()
  }
}

const limpiarHistorialGlobal = async () => {
  if(confirm("¿Estás seguro de querer borrar todo el registro de dados de esta sesión?")) {
    const { error } = await supabase.from('campaigns').update({ historial_dados: [] }).eq('id', campaignId).select('id').single()
    if (error) return avisar('No se pudo borrar el historial.', true)
    historialCompartido.value = []
  }
}

const modalVisionAbierto = ref(false)
const urlVisionLibre = ref('')

const compartirVisionLibre = () => {
  if (!urlVisionLibre.value) return
  estadoMesa.value.entidadVisible = {
    nombre: 'Visión del DM',
    imagen: urlVisionLibre.value
  }
  guardarMesaDb() 
  modalVisionAbierto.value = false
  urlVisionLibre.value = '' 
}

const manejarProyeccionVision = (payload) => {
  estadoMesa.value.entidadVisible = { nombre: payload.nombre, imagen: payload.imagen }
  guardarMesaDb()
}

const manejarProyeccionTienda = (payload) => {
  estadoMesa.value.tiendaVisible = { id: payload.id, sesion: idOperacion(), targets: 'all', nombre: payload.nombreLugar, inventario: payload.inventario }
  guardarMesaDb()
  modalTiendasAbierto.value = false
}

onMounted(() => { cargarMesaDM() })
</script>

<template>
  <div class="mesa-dm-pantalla" :class="{'drawer-open': drawerAbierto}">
    <div class="filtro-oscuro"></div>
    <div v-if="cargando" class="cargando">Abriendo grimorio de campaña...</div>
    <div v-else-if="errorCarga" class="estado-partida">No se pudo abrir la mesa. <button @click="cargarMesaDM">Reintentar</button><NuxtLink to="/dashboard">Volver</NuxtLink></div>
    <div v-else class="layout-dm">
      
      <div class="panel-superior">
        <div class="header-izq">
          <button @click="router.push(`/campanas/${route.params.id}`)" class="btn-ghost">← Salir</button>
          <h1 class="titulo-dm">Mesa del DM: <span class="campana-name">{{ campana.nombre_campanya || campana.nombre }}</span></h1>
          <div class="toggle-oculto">
            <span class="lbl-oculto">Ocultar Dados</span>
            <label class="switch"><input type="checkbox" v-model="dadosOcultos"><span class="slider round"></span></label>
          </div>
          <div v-if="estadoMesa.entidadVisible" class="indicador-vision">
            <span>👁️ Mostrando: <strong>{{ estadoMesa.entidadVisible.nombre }}</strong></span>
            <button @click="limpiarVisionJugadores">✖ Ocultar</button>
          </div>
        </div>
        <div class="botones-dm-acciones">
          <button @click="modalVisionAbierto = true" class="btn-ghost">👁️ Proyectar Imagen</button>
          <button v-if="!combateActivo" @click="prepararIniciativa" class="btn-accion-dm dorado">⚔️ INICIATIVA</button>
          <button v-else @click="terminarCombate" class="btn-accion-dm rojo">🛑 Fin Combate</button>
          <button class="btn-control tienda" @click="modalTiendasAbierto = true">🏰 Ciudad</button>
          <button @click="modalAgregarJugadorAbierto = true" class="btn-accion-dm azul">+ Añadir PJ</button>
          <button @click="modalAgregarNpcAbierto = true" class="btn-accion-dm verde">+ Añadir NPC</button>
          <button @click="modalAgregarEnemigoAbierto = true" class="btn-accion-dm rojo">+ Añadir Enemigo</button>
        </div>
      </div>

      <section v-if="pedidos.length || estadoMesa.tiendaVisible" class="pedidos-mesa">
        <button v-if="estadoMesa.tiendaVisible" @click="estadoMesa.tiendaVisible = null; guardarMesaDb()">Cerrar tienda proyectada</button>
        <article v-for="([id, pedido]) in pedidos" :key="pedido.id">
          <strong>{{ todosLosPjsDeCampana.find(p => p.id === id)?.nombre_pj || 'Aventurero' }}</strong>
          <span>{{ (pedido.items || []).map(i => (i.unidades || 1) + ' × ' + i.nombre).join(', ') }} · {{ pedido.total }} pc</span>
          <small v-if="pedido.patrocinador">Paga {{ todosLosPjsDeCampana.find(p => p.id === pedido.patrocinador)?.nombre_pj }}</small>
          <small v-if="!pedido.id || !pedido.tienda">Pedido anterior. Volvé a proyectar el catálogo para renovarlo.</small>
          <button :disabled="resolviendo || !pedido.id || !pedido.tienda" @click="resolverPedido(id, pedido, true)">Aprobar</button>
          <button :disabled="resolviendo" @click="resolverPedido(id, pedido, false)">Rechazar</button>
        </article>
      </section>

      <DmTrackerIniciativa 
        v-if="combateActivo"
        :ordenIniciativa="ordenIniciativa" 
        :turnoActual="turnoActual"
        @siguiente-turno="siguienteTurno" 
      />

      <div class="tablero-grid">
        <div class="row-superior-pjs" v-if="jugadoresSuperiores.length > 0">
          <div v-for="pj in jugadoresSuperiores" :key="pj.id" class="mini-card-pj" @click="abrirDrawer(pj, 'pj', 'right')">
            <button class="btn-sacar-tablero" @click.stop="desvincular(pj.id, 'pj')">✖</button>
            <img v-if="pj.imagen_url" :src="pj.imagen_url" class="card-avatar" /><div v-else class="card-fallback">🛡️</div>
            <div class="card-info">
              <h3>{{ pj.nombre_pj }}</h3>
              <div class="hp-direct-box relative" @click.stop>
                <span v-if="tooltipActivo === pj.id" class="hp-tooltip">↵ Enter para guardar</span>
                <input type="number" v-model="pj.hp_actual" @focus="tooltipActivo = pj.id" @blur="tooltipActivo = null" @keyup.enter="$event.target.blur()" @change="guardarHpYQuitarFoco($event, pj, 'pj')" class="input-hp-rapido"/>
                <span>/ {{ pj.hp_max }}</span>
              </div>
            </div>
          </div>
        </div>

        <div class="cuerpo-tablero">
          <div class="columna-pjs">
            <h4 class="col-titulo">Grupo (Izq)</h4>
            <div v-for="pj in jugadoresIzquierda" :key="pj.id" class="mini-card-pj" @click="abrirDrawer(pj, 'pj', 'left')">
              <button class="btn-sacar-tablero" @click.stop="desvincular(pj.id, 'pj')">✖</button>
              <img v-if="pj.imagen_url" :src="pj.imagen_url" class="card-avatar" /><div v-else class="card-fallback">🛡️</div>
              <div class="card-info">
                <h3>{{ pj.nombre_pj }}</h3>
                <div class="hp-bar-container"><div class="hp-bar-fill" :style="{width: (pj.hp_actual / Math.max(1, pj.hp_max)) * 100 + '%'}"></div></div>
                <div class="hp-direct-box relative" @click.stop>
                  <span v-if="tooltipActivo === pj.id" class="hp-tooltip">↵ Enter</span>
                  <input type="number" v-model="pj.hp_actual" @focus="tooltipActivo = pj.id" @blur="tooltipActivo = null" @keyup.enter="$event.target.blur()" @change="guardarHpYQuitarFoco($event, pj, 'pj')" class="input-hp-rapido"/>
                  <span>/ {{ pj.hp_max }}</span>
                </div>
                <div class="efectos-mini" v-if="pj.efectos && pj.efectos.length > 0">
                  <span v-for="e in pj.efectos" :key="e.id" :title="e.nombre">{{ e.icono }} {{ e.nombre }}</span>
                </div>
              </div>
            </div>
          </div>

          <DmMesaDados 
            :historialCompartido="historialCompartido"
            :todasLasEntidadesActivas="todasLasEntidadesActivas"
            :dmDadosEnMesa="dmDadosEnMesa"
            :dmTirando="dmTirando"
            :dmResultadoFinal="dmResultadoFinal"
            :dmPool="dmPool"
            v-model:dmBono="dmBono"
            @limpiar-historial="limpiarHistorialGlobal"
            @aplicar-dano="aplicarDano"
            @curar-dano="curarDano"
            @aplicar-efecto="aplicarEfectoDesdeHistorial"
            @agregar-dado="agregarDadoDm"
            @limpiar-pool="limpiarPoolDm"
            @tirar-pool="tirarPoolDm"
          />

          <div class="columna-pjs">
            <h4 class="col-titulo">Grupo (Der)</h4>
            <div v-for="pj in jugadoresDerecha" :key="pj.id" class="mini-card-pj" @click="abrirDrawer(pj, 'pj', 'right')">
              <button class="btn-sacar-tablero" @click.stop="desvincular(pj.id, 'pj')">✖</button>
              <img v-if="pj.imagen_url" :src="pj.imagen_url" class="card-avatar" /><div v-else class="card-fallback">🛡️</div>
              <div class="card-info">
                <h3>{{ pj.nombre_pj }}</h3>
                <div class="hp-bar-container"><div class="hp-bar-fill" :style="{width: (pj.hp_actual / Math.max(1, pj.hp_max)) * 100 + '%'}"></div></div>
                <div class="hp-direct-box relative" @click.stop>
                  <span v-if="tooltipActivo === pj.id" class="hp-tooltip">↵ Enter</span>
                  <input type="number" v-model="pj.hp_actual" @focus="tooltipActivo = pj.id" @blur="tooltipActivo = null" @keyup.enter="$event.target.blur()" @change="guardarHpYQuitarFoco($event, pj, 'pj')" class="input-hp-rapido"/>
                  <span>/ {{ pj.hp_max }}</span>
                </div>
                <div class="efectos-mini" v-if="pj.efectos && pj.efectos.length > 0">
                  <span v-for="e in pj.efectos" :key="e.id" :title="e.nombre">{{ e.icono }} {{ e.nombre }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="fila-inferior-dm">
          <div class="seccion-tablero-baja verde-borde">
            <h3 class="baja-titulo t-verde">NPCs de la Sesión</h3>
            <div class="lista-baja-cards">
              <div v-for="npc in npcsActivos" :key="npc.instance_id" class="mini-card-pj custom-card" @click="abrirDrawer(npc, 'npc', 'left')">
                <button class="btn-sacar-tablero" @click.stop="desvincular(npc.instance_id, 'npc')">✖</button>
                <img v-if="npc.imagen_url" :src="npc.imagen_url" class="card-avatar" /><div v-else class="card-fallback fallback-npc">👤</div>
                <div class="card-info">
                  <h3>{{ npc.nombre_pj }}</h3>
                  <div class="hp-direct-box relative" @click.stop>
                    <span v-if="tooltipActivo === npc.instance_id" class="hp-tooltip">↵ Enter</span>
                    <input type="number" v-model="npc.hp_actual" @focus="tooltipActivo = npc.instance_id" @blur="tooltipActivo = null" @keyup.enter="$event.target.blur()" @change="guardarHpYQuitarFoco($event, npc, 'npc')" class="input-hp-rapido"/>
                    <span>/ {{ npc.hp_max }}</span>
                  </div>
                  <div class="efectos-mini" v-if="npc.efectos && npc.efectos.length > 0">
                    <span v-for="e in npc.efectos" :key="e.id" :title="e.nombre">{{ e.icono }} {{ e.nombre }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="seccion-tablero-baja rojo-borde">
            <h3 class="baja-titulo t-rojo">Enemigos / Monstruos</h3>
            <div class="lista-baja-cards">
              <div v-for="en in enemigosActivos" :key="en.instance_id" class="mini-card-pj custom-card" @click="abrirDrawer(en, 'enemigo', 'right')">
                <button class="btn-sacar-tablero" @click.stop="desvincular(en.instance_id, 'enemigo')">✖</button>
                <img v-if="en.imagen_url" :src="en.imagen_url" class="card-avatar" /><div v-else class="card-fallback fallback-en">💀</div>
                <div class="card-info">
                  <h3>{{ en.nombre_pj }}</h3>
                  <div class="hp-direct-box relative" @click.stop>
                    <span v-if="tooltipActivo === en.instance_id" class="hp-tooltip">↵ Enter</span>
                    <input type="number" v-model="en.hp_actual" @focus="tooltipActivo = en.instance_id" @blur="tooltipActivo = null" @keyup.enter="$event.target.blur()" @change="guardarHpYQuitarFoco($event, en, 'enemigo')" class="input-hp-rapido"/>
                    <span>/ {{ en.hp_max }}</span>
                  </div>
                  <div class="efectos-mini" v-if="en.efectos && en.efectos.length > 0">
                    <span v-for="e in en.efectos" :key="e.id" :title="e.nombre">{{ e.icono }} {{ e.nombre }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <NotasDM :campaignId="route.params.id" />

      </div>
    </div>

    <div class="drawer-overlay" v-if="drawerAbierto" @click="drawerAbierto = false"></div>
    <DmDrawerDetalles 
      v-if="drawerAbierto"
      :drawerLado="drawerLado"
      :entidadActiva="entidadActiva"
      :tipoEntidadActiva="tipoEntidadActiva"
      :tooltipActivo="tooltipActivo"
      :todosEfectos="todosEfectos"
      :ataquesFiltradosDrawer="ataquesFiltradosDrawer"
      v-model:efectoAInsertar="efectoAInsertar"
      v-model:filtroAtaquesDrawer="filtroAtaquesDrawer"
      @cerrar="drawerAbierto = false"
      @mostrar-jugadores="mostrarAJugadores"
      @set-tooltip="(val) => tooltipActivo = val"
      @guardar-hp="guardarHpYQuitarFoco"
      @agregar-efecto="agregarEfectoManual"
      @quitar-efecto="quitarEfectoManual"
      @tirar-stat="tirarStat"
      @tirar-ataque="tirarAtaque"
      @tirar-dano="tirarDano"
      @abrir-ficha="abrirFichaNuevaPestana"
    />

    <div v-if="modalIniciativaAbierto" class="modal-dm-overlay" @click.self="modalIniciativaAbierto = false">
      <div class="modal-dm-sheet form-medium">
        <h3>Llamado a la Batalla (Iniciativa)</h3>
        <div class="lista-vincular check-lista">
          <label v-for="ent in todasLasEntidadesActivas" :key="ent.instance_id || ent.id" class="item-check">
            <input type="checkbox" :value="ent.instance_id || ent.id" v-model="seleccionIniciativa">
            <span :class="{'t-verde': ent.tipo==='npc', 't-rojo': ent.tipo==='enemigo'}">{{ ent.nombre_pj }}</span>
          </label>
        </div>
        <button class="btn-guardar-creacion dorado" @click="lanzarIniciativaGlobal">🎲 TIRAR INICIATIVA</button>
      </div>
    </div>

    <div v-if="modalAgregarJugadorAbierto" class="modal-dm-overlay" @click.self="modalAgregarJugadorAbierto = false">
      <div class="modal-dm-sheet form-medium">
        <h3>Llamar Jugador a la Mesa</h3>
        <input type="text" v-model="filtroPj" placeholder="Buscar héroe..." class="input-search-modal" />
        <div class="lista-vincular-grande">
          <div v-for="p in pjsFiltrados" :key="p.id" class="item-vincular-gigante">
            <img v-if="p.imagen_url" :src="p.imagen_url" class="img-add-grande" />
            <div v-else class="img-add-fallback">🛡️</div>
            <div class="info-add-grande">
              <h4>{{ p.nombre_pj }}</h4>
              <p>{{ p.raza }} {{ p.clase }} (Nvl {{ p.nivel }})</p>
            </div>
            <button class="btn-add-express" @click="agregarAlTablero(p, 'pj')">Añadir</button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="modalAgregarNpcAbierto" class="modal-dm-overlay" @click.self="modalAgregarNpcAbierto = false">
      <div class="modal-dm-sheet form-medium">
        <h3>Invocar NPC</h3>
        <div class="filtros-modal-row">
          <input type="text" v-model="filtroNpc.nombre" placeholder="Nombre..." class="input-search-modal" />
          <input type="text" v-model="filtroNpc.dificultad" placeholder="CR" class="input-search-modal corto" />
        </div>
        <div class="lista-vincular-grande">
          <div v-for="n in npcsFiltrados" :key="n.id" class="item-vincular-gigante borde-verde">
            <img v-if="n.imagen_url" :src="n.imagen_url" class="img-add-grande" />
            <div v-else class="img-add-fallback">👤</div>
            <div class="info-add-grande">
              <h4>{{ n.nombre_pj }}</h4>
              <p>Clase: {{ n.clase || '-' }} | CR: {{ n.dificultad || '-' }}</p>
            </div>
            <button class="btn-add-express verde" @click="agregarAlTablero(n, 'npc')">Añadir</button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="modalAgregarEnemigoAbierto" class="modal-dm-overlay" @click.self="modalAgregarEnemigoAbierto = false">
      <div class="modal-dm-sheet form-medium">
        <h3>Desatar Enemigo</h3>
        <div class="filtros-modal-row">
          <input type="text" v-model="filtroEnemigo.nombre" placeholder="Nombre..." class="input-search-modal" />
          <input type="text" v-model="filtroEnemigo.dificultad" placeholder="CR" class="input-search-modal corto" />
        </div>
        <div class="lista-vincular-grande">
          <div v-for="e in enemigosFiltrados" :key="e.id" class="item-vincular-gigante borde-rojo">
            <img v-if="e.imagen_url" :src="e.imagen_url" class="img-add-grande" />
            <div v-else class="img-add-fallback rojo">💀</div>
            <div class="info-add-grande">
              <h4>{{ e.nombre_pj }}</h4>
              <p>Clase: {{ e.clase || '-' }} | CR: {{ e.dificultad || '-' }}</p>
            </div>
            <button class="btn-add-express rojo" @click="agregarAlTablero(e, 'enemigo')">Añadir</button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="modalVisionAbierto" class="modal-dm-overlay" @click.self="modalVisionAbierto = false">
      <div class="modal-dm-sheet form-medium">
        <h3>👁️ Proyectar Visión a los Jugadores</h3>
        <p class="txt-gris mb-corto">Pega un link de internet para mostrar una imagen temporal en la pantalla de todos.</p>
        
        <input type="text" v-model="urlVisionLibre" placeholder="URL de la imagen (ej: https://...)" class="input-search-modal mb-corto" />
        
        <div v-if="urlVisionLibre" class="preview-imagen">
          <img :src="urlVisionLibre" alt="Preview" />
        </div>

        <div class="acciones-modal">
          <button class="btn-cancelar" @click="modalVisionAbierto = false">Cancelar</button>
          <button class="btn-accion-dm dorado" @click="compartirVisionLibre">Proyectar ahora</button>
        </div>
      </div>
    </div>

    <GestorTiendasDM 
      v-if="modalTiendasAbierto" 
      :campaignId="route.params.id"
      :jugadores="personajesActivos"
      @cerrar="modalTiendasAbierto = false"
      @proyectarVision="manejarProyeccionVision"
      @proyectarTienda="manejarProyeccionTienda"
    />

  </div>
</template>