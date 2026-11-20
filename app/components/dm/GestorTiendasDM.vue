<script setup>
import { ref, computed, onMounted } from 'vue'

const props = defineProps({
  campaignId: { type: String, required: true },
  jugadores: { type: Array, required: true } // Recibe personajesActivos de la mesa
})

const emit = defineEmits(['cerrar', 'proyectarVision', 'proyectarTienda'])
const supabase = useSupabaseClient()

// --- ESTADOS DE NAVEGACIÓN ---
const { avisar } = useAvisos()
const vendiendo = ref(false)
let operacion = ''
let contenidoOperacion = ''
let consultaTienda = 0
const ciudades = ref([])
const ciudadSeleccionadaId = ref('')
const tiendasUrbana = ref([])
const filtroTiendaStr = ref('')

const tiendaFoco = ref(null) // Local inspeccionándose
const personalCargado = ref([])
const inventarioCargado = ref([]) // IDs resueltos contra la BD real

// --- MECÁNICAS DE DADOS Y JUGADORES EN TIENDA ---
const dadoSimuladoForm = ref(10) // Valor d20 para simular visibilidad rápida
const mostrarSoloSugeridos = ref(false)

// --- REGISTRO DE TRATOS (CARRITO DE COBRO) ---
const mesaTratos = ref([])

const totalTrato = computed(() => mesaTratos.value.reduce((total, linea) => total + linea.precio_unidad_cobre * linea.unidades, 0))

const tiendasFiltradas = computed(() => {
  return tiendasUrbana.value.filter(t => 
    (t.nombre_personalizado || t.tipo).toLowerCase().includes(filtroTiendaStr.value.toLowerCase())
  )
})

// --- MÉTODOS DE BASE DE DATOS ---
const inicializarComercio = async () => {
  const { data: ciu } = await supabase.from('ciudades').select('*').order('nombre')
  if (ciu) {
    ciudades.value = ciu
    if (ciu.length > 0) {
      ciudadSeleccionadaId.value = ciu[0].id
      actualizarCalles()
    }
  }
}

const actualizarCalles = async () => {
  const ciudad = ciudadSeleccionadaId.value
  consultaTienda++
  mesaTratos.value = []
  filtroTiendaStr.value = ''
  tiendaFoco.value = null
  tiendasUrbana.value = []
  if (!ciudad) return
  const { data } = await supabase.from('tiendas_sesion').select('*').eq('ciudad_id', ciudadSeleccionadaId.value).eq('campaign_id', props.campaignId).order('tipo')
  if (data && ciudad === ciudadSeleccionadaId.value) tiendasUrbana.value = data
}

// --- INSPECCIONAR ESTABLECIMIENTO ---
const inspeccionarComercio = async (tienda) => {
  if (vendiendo.value && tiendaFoco.value?.id !== tienda.id) return
  const consulta = ++consultaTienda
  tiendaFoco.value = tienda
  mesaTratos.value = []
  personalCargado.value = []
  inventarioCargado.value = []

  // 1. Cargar Empleados vinculados
  if (tienda.empleados && tienda.empleados.length > 0) {
    const { data } = await supabase.from('characters').select('id, nombre_pj, raza, nivel').in('id', tienda.empleados.map(e => e.id ?? e))
    if (consulta !== consultaTienda) return
    if (data) personalCargado.value = data
  }

  // 2. Resolver inventario relacional (IDs -> Datos reales)
  const refsGuardadas = tienda.inventario_actual || []
  if (refsGuardadas.length > 0) {
    const idsBase = refsGuardadas.filter(i => i.tabla === 'items_base').map(i => i.item_id)
    const idsCustom = refsGuardadas.filter(i => i.tabla === 'items_jugadores').map(i => i.item_id)

    let catBase = [], catCustom = []
    if (idsBase.length > 0) {
      const { data } = await supabase.from('items_base').select('*').in('id', idsBase)
      if (data) catBase = data
    }
    if (idsCustom.length > 0) {
      const { data } = await supabase.from('items_jugadores').select('*').in('id', idsCustom)
      if (data) catCustom = data
    }

    // Unimos los datos maestros de la BD con el stock transaccional de esta tienda
    if (consulta !== consultaTienda) return
    inventarioCargado.value = refsGuardadas.map(rg => {
      let datosMaestros = rg.tabla === 'items_base'
        ? catBase.find(b => b.id === rg.item_id)
        : catCustom.find(c => c.id === rg.item_id)

      if (!datosMaestros) return null
      return { 
        ...datosMaestros, 
        stock_local: rg.cantidad, 
        tabla_origen: rg.tabla,
        revelado: false // Por defecto oculto hasta evaluar tirada
      }
    }).filter(Boolean)
  }
}

// --- CONTROL DE REVELACIÓN POR ENTRADA DE DADOS ---
const evaluarVisionPorDados = () => {
  const tiro = dadoSimuladoForm.value
  inventarioCargado.value.forEach(item => {
    const dificultadTeorica = (item.nivel_objeto || item.nivel || 0) * 2 + 8
    if (tiro >= dificultadTeorica || tiro >= 20) {
      item.revelado = true
    }
  })
}

const forzarRevelacionTotal = (estado) => {
  inventarioCargado.value.forEach(i => i.revelado = estado)
}

// --- CONTROL DE FACTURACIÓN (CARRITO) ---
const empujarAlCarrito = (item) => {
  if (item.stock_local <= 0) return avisar("No queda stock disponible.", true)
  
  // Si ya está, sumamos cantidad
  const existente = mesaTratos.value.find(t => t.item_id === item.id && t.ref_item_sistema.tabla_origen === item.tabla_origen)
  if (existente) {
    if (existente.unidades < item.stock_local) existente.unidades++
    return
  }

  mesaTratos.value.push({
    item_id: item.id,
    nombre: item.nombre,
    unidades: 1,
    precio_unidad_cobre: item.precio_cobre || 0,
    comprador_id: props.jugadores.length > 0 ? props.jugadores[0].id : '',
    ref_item_sistema: item
  })
}

const removerDelCarrito = (idx) => {
  mesaTratos.value.splice(idx, 1)
}

// --- CIERRE DE TRATO: PROCESAMIENTO MATEMÁTICO D&D 5E ---
const venderYTransferir = async () => {
  if (vendiendo.value || !tiendaFoco.value || !mesaTratos.value.length) return
  const lineas = mesaTratos.value.map(t => ({
    item_id: t.item_id, tabla: t.ref_item_sistema.tabla_origen, comprador: t.comprador_id,
    precio: t.precio_unidad_cobre, unidades: t.unidades
  }))
  if (lineas.some(t => !t.comprador || !Number.isSafeInteger(t.precio) || t.precio < 0 ||
    !Number.isSafeInteger(t.unidades) || t.unidades < 1)) return avisar('Revisá el comprador, la cantidad y el precio.', true)
  vendiendo.value = true
  const tienda = tiendaFoco.value
  const contenido = JSON.stringify([tienda.id, lineas])
  if (!operacion || contenido !== contenidoOperacion) operacion = idOperacion()
  contenidoOperacion = contenido
  try {
    const { error } = await supabase.rpc('dnd_vender', { p_campana: props.campaignId, p_tienda: String(tienda.id),
      p_lineas: lineas, p_operacion: operacion })
    if (error) throw error
    operacion = ''
    mesaTratos.value = []
    avisar('Trato cerrado. El inventario y el saldo ya están actualizados.')
    const { data, error: errorStock } = await supabase.from('tiendas_sesion').select('*').eq('id', tienda.id).single()
    if (errorStock) throw errorStock
    Object.assign(tienda, data)
    await inspeccionarComercio(tienda)
  } catch (e) { avisar(e.message, true) }
  finally { vendiendo.value = false }
}

const proyectarAlTableroGeneral = () => {
  if (!tiendaFoco.value) return
  emit('proyectarTienda', {
    id: tiendaFoco.value.id,
    nombreLugar: tiendaFoco.value.nombre_personalizado || tiendaFoco.value.tipo,
    inventario: inventarioCargado.value.filter(i => i.revelado)
  })
  avisar('Catálogo proyectado en la mesa.')
}

onMounted(() => { inicializarComercio() })
</script>

<template>
  <div class="modal-tienda-dm-overlay" @click.self="!vendiendo && emit('cerrar')">
    <div class="hoja-registro-dm" :inert="vendiendo" :aria-busy="vendiendo">
      
      <div class="control-ciudades-bar flex-between">
        <div class="flex-align">
          <span class="t-dorado font-cinzel text-lg mr-1">🏰 Asentamiento:</span>
          <select v-model="ciudadSeleccionadaId" @change="actualizarCalles" class="select-dm-comercio">
            <option v-for="c in ciudades" :key="c.id" :value="c.id">{{ c.nombre }} ({{ (c.tamano || 'pueblo').toUpperCase() }})</option>
          </select>
        </div>
        <div class="buscador-caja-tienda">
          <input type="text" v-model="filtroTiendaStr" placeholder="Buscar local…" class="input-dm-comercio" />
        </div>
        <button class="btn-cerrar-tiendas" @click="emit('cerrar')">Cerrar</button>
      </div>

      <div class="cuerpo-interactivo-comercial">
        
        <div class="lista-tiendas-calles">
          <h4 class="titulo-seccion-comercio">Establecimientos Abiertos</h4>
          <div class="scroll-tiendas-comercio">
            <div v-if="tiendasFiltradas.length === 0" class="aviso-vacio">{{ filtroTiendaStr ? 'Ningún local coincide.' : 'No hay locales en esta ciudad.' }}</div>
            <div 
              v-for="t in tiendasFiltradas" 
              :key="t.id" 
              :class="['tarjeta-tienda-dm-mesa', tiendaFoco?.id === t.id ? 'activo' : '']"
              role="button" tabindex="0" @keydown.enter.prevent="inspeccionarComercio(t)" @keydown.space.prevent="inspeccionarComercio(t)" @click="inspeccionarComercio(t)"
            >
              <div class="iconografia-comercio">🏪</div>
              <div class="info-comercio-card">
                <h5>{{ t.nombre_personalizado || t.tipo }}</h5>
                <span class="badge-comercio">{{ t.tipo }}</span>
              </div>
            </div>
          </div>
        </div>

        <div class="interior-tienda-dm">
          <div v-if="!tiendaFoco" class="flex-center h-full text-muted">
            <p class="font-cinzel">Elegí un local para ver su inventario.</p>
          </div>
          
          <div v-else class="layout-interior-tienda">
            <div class="header-comercio-activo flex-between">
              <div>
                <h3>{{ tiendaFoco.nombre_personalizado || tiendaFoco.tipo }}</h3>
                <p class="txt-gris txt-chico">Rubro · <strong>{{ tiendaFoco.tipo }}</strong></p>
              </div>
              <button class="btn-proyectar" @click="proyectarAlTableroGeneral">📡 Proyectar Catálogo Revelado</button>
            </div>

            <div class="sub-grid-tienda-interna">
              <div class="entorno-comercial-dados">
                <h4 class="border-bottom pb-corto mb-1">Plantilla de Personal</h4>
                <div class="mini-scroll-entidades">
                  <div v-if="personalCargado.length === 0" class="aviso-sin-personal">Local cerrado / Sin empleados.</div>
                  <div v-for="emp in personalCargado" :key="emp.id" class="item-personal-tienda">
                    <span class="avatar-mini-p">👤</span>
                    <div>
                      <h6>{{ emp.nombre_pj }}</h6>
                      <small>{{ emp.raza }} Nvl {{ emp.nivel }}</small>
                    </div>
                  </div>
                </div>

                <h4 class="border-bottom pb-corto mb-1 mt-1">Inspección de Vitrinas</h4>
                <div class="caja-mecanica-dados-comercio">
                  <label class="txt-chico txt-gris d-block mb-corto">Ingresa la tirada de Investigación/Perspicacia grupal:</label>
                  <div class="flex-align mb-corto">
                    <input type="number" v-model.number="dadoSimuladoForm" class="input-dm-comercio text-center mr-1" style="width: 70px" min="1" max="30" />
                    <button class="btn-evaluar-dados" @click="evaluarVisionPorDados">🎲 Evaluar Filtro</button>
                  </div>
                  <div class="flex-between mt-1">
                    <button class="btn-util-comercio" @click="forzarRevelacionTotal(true)">👁️ Revelar Todo</button>
                    <button class="btn-util-comercio rojo" @click="forzarRevelacionTotal(false)">🔒 Ocultar Todo</button>
                  </div>
                </div>
              </div>

              <div class="aparador-artculos-comercio">
                <div class="flex-between border-bottom pb-corto mb-1">
                  <h4 class="margin-0">Aparador de Mercancías</h4>
                  <label class="checkbox-lugar border-none padding-0 margin-0 background-none">
                    <input type="checkbox" v-model="mostrarSoloSugeridos" />
                    <span class="txt-chico text-oro">Solo Revelados</span>
                  </label>
                </div>

                <div class="scroll-aparador-comercio">
                  <div v-if="inventarioCargado.length === 0" class="aviso-vacio">El inventario de este comercio está desprovisto de objetos.</div>
                  
                  <div 
                    v-for="item in inventarioCargado" 
                    :key="item.tabla_origen + item.id" 
                    v-show="!mostrarSoloSugeridos || item.revelado"
                    :class="['fila-articulo-dm-tienda', item.revelado ? 'revelado' : 'oculto']"
                  >
                    <button class="btn-ojo-toggle" :aria-label="`Revelar ${item.nombre}`" :aria-pressed="item.revelado" @click="item.revelado = !item.revelado">
                      {{ item.revelado ? '👁️' : '🔒' }}
                    </button>
                    <div class="flex-1 ml-1 overflow-hidden">
                      <strong class="text-white text-ellipsis">{{ item.nombre }}</strong>
                      <div class="txt-chico txt-gris">
                        Stock: <strong>{{ item.stock_local }}</strong> | Nvl {{ item.nivel_objeto || item.nivel || 0 }} | <span class="text-oro">{{ item.bono || '-' }}</span>
                      </div>
                    </div>
                    <div class="precio-cobre-tag text-oro monospace">
                      💰 {{ item.precio_cobre }}pc
                    </div>
                    <button class="btn-agregar-negociacion" :aria-label="`Agregar ${item.nombre} al trato`" @click="empujarAlCarrito(item)" :disabled="item.stock_local <= 0">+</button>
                  </div>
                </div>
              </div>
            </div>

          </div>
        </div>

        <div class="caja-facturacion-negociacion">
          <h4 class="titulo-seccion-comercio border-bottom pb-corto text-center">⚖️ Mesa de Negociación</h4>
          
          <div v-if="mesaTratos.length === 0" class="caja-carrito-vacía">
            Usá el botón + junto a un objeto para agregarlo al trato.
          </div>

          <div class="scroll-facturacion" v-else>
            <div v-for="(trato, idx) in mesaTratos" :key="trato.ref_item_sistema.tabla_origen + trato.item_id" class="tarjeta-factura-item mb-1">
              <div class="flex-between mb-corto">
                <span class="text-white font-bold text-sm text-ellipsis" style="width: 80%">{{ trato.nombre }}</span>
                <button class="btn-quitar-factura" @click="removerDelCarrito(idx)">✖</button>
              </div>

              <div class="input-group-comercio mb-corto">
                <label>Héroe que Paga:</label>
                <select v-model="trato.comprador_id" class="select-dm-comercio compact w-full">
                  <option v-for="pj in props.jugadores" :key="pj.id" :value="pj.id">{{ pj.nombre_pj }}</option>
                </select>
              </div>

              <div class="flex-between gap-1">
                <div class="input-group-comercio w-40">
                  <label>Cant:</label>
                  <input type="number" v-model.number="trato.unidades" class="input-dm-comercio compact text-center w-full" min="1" :max="trato.ref_item_sistema.stock_local" />
                </div>
                <div class="input-group-comercio w-60">
                  <label>Precio Pactado (pc):</label>
                  <input type="number" v-model.number="trato.precio_unidad_cobre" class="input-dm-comercio compact text-center w-full text-oro" />
                </div>
              </div>
              <div class="subtotal-item-factura text-right text-xs txt-gris mt-corto">
                Subtotal: <span class="text-oro font-bold">{{ trato.precio_unidad_cobre * trato.unidades }} pc</span>
              </div>
            </div>
          </div>

          <p v-if="mesaTratos.length" class="total-trato">Total del trato <strong>{{ totalTrato }} pc</strong></p>
          <button v-if="mesaTratos.length > 0" @click="venderYTransferir" :disabled="vendiendo" class="btn-cerrar-trato-dorado">
            {{ vendiendo ? 'Cobrando…' : 'Cerrar trato y cobrar' }}
          </button>
        </div>

      </div>

    </div>
  </div>
</template>

<style scoped>
.modal-tienda-dm-overlay { position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; background: rgba(0,0,0,0.85); z-index: 999; display: flex; justify-content: center; align-items: center; padding: 20px; box-sizing: border-box; }
.hoja-registro-dm { width: 1300px; max-width: 98vw; height: 90vh; background: #070709; border: 2px solid #b45309; border-radius: 12px; display: flex; flex-direction: column; overflow: hidden; box-shadow: 0 0 40px rgba(0,0,0,0.9); color: #e2e8f0; font-family: 'Inter', sans-serif; }

/* REPOSITORIO COMERCIAL SUPERIOR */
.control-ciudades-bar { background: #0f0f13; border-bottom: 1px solid #1e293b; padding: 12px 20px; gap: 15px; flex-shrink: 0; }
.font-cinzel { font-family: 'Cinzel', serif; }
.select-dm-comercio { background: #000; border: 1px solid #b45309; color: #facc15; padding: 6px 12px; border-radius: 6px; outline: none; font-weight: bold; }
.input-dm-comercio { background: #000; border: 1px solid #334155; color: white; padding: 8px 12px; border-radius: 6px; outline: none; }
.input-dm-comercio:focus { border-color: #facc15; }
.input-dm-comercio.compact { padding: 4px 6px; font-size: 0.85rem; }
.btn-cerrar-tiendas { background: #7f1d1d; border: 1px solid #ef4444; color: white; font-weight: bold; padding: 6px 14px; border-radius: 6px; cursor: pointer; }

/* CUERPO INTERACTIVO */
.cuerpo-interactivo-comercial { display: grid; grid-template-columns: 280px 1fr 320px; flex: 1; overflow: hidden; background: #030304; }

/* SECCIONES COMPARTIDAS */
.lista-tiendas-calles { border-right: 1px solid #1e293b; display: flex; flex-direction: column; background: #09090c; }
.interior-tienda-dm { display: flex; flex-direction: column; background: #030304; overflow: hidden; }
.caja-facturacion-negociacion { border-left: 1px solid #1e293b; background: rgba(180, 83, 9, 0.02); display: flex; flex-direction: column; padding: 15px; overflow: hidden; }

.titulo-seccion-comercio { font-family: 'Cinzel', serif; color: #facc15; font-size: 1rem; margin: 0; padding: 12px; background: rgba(0,0,0,0.2); border-bottom: 1px solid #1e293b; }

/* TARJETAS TIENDA */
.scroll-tiendas-comercio { display: flex; flex-direction: column; gap: 8px; overflow-y: auto; flex: 1; padding: 10px; }
.tarjeta-tienda-dm-mesa { display: flex; align-items: center; gap: 12px; background: #121216; border: 1px solid #232329; padding: 10px; border-radius: 8px; cursor: pointer; transition: 0.2s; }
.tarjeta-tienda-dm-mesa:hover { border-color: #3b82f6; background: #16161c; }
.tarjeta-tienda-dm-mesa.activo { border-color: #b45309; background: rgba(180, 83, 9, 0.1); box-shadow: inset 0 0 10px rgba(180,83,9,0.2); }
.iconografia-comercio { font-size: 1.4rem; }
.info-comercio-card h5 { margin: 0 0 2px 0; font-size: 0.9rem; color: #fff; white-space: nowrap; text-overflow: ellipsis; overflow: hidden; }
.badge-comercio { font-size: 0.7rem; color: #94a3b8; background: #1e293b; padding: 1px 6px; border-radius: 10px; display: inline-block; }

/* VISTA INTERIOR COMERCIO */
.layout-interior-tienda { display: flex; flex-direction: column; height: 100%; overflow: hidden; }
.header-comercio-activo { padding: 15px; border-bottom: 1px solid #1e293b; background: rgba(0,0,0,0.1); flex-shrink: 0; }
.header-comercio-activo h3 { margin: 0; font-family: 'Cinzel', serif; color: #fff; }
.btn-proyectar { background: #1e3a8a; border: 1px solid #3b82f6; color: white; padding: 6px 12px; border-radius: 6px; font-size: 0.8rem; font-weight: bold; cursor: pointer; }
.btn-proyectar:hover { background: #2563eb; }

.sub-grid-tienda-interna { display: grid; grid-template-columns: 240px 1fr; gap: 15px; flex: 1; overflow: hidden; padding: 15px; }

/* COL INTERNA DADOS */
.entorno-comercial-dados { border-right: 1px solid #1e293b; padding-right: 15px; display: flex; flex-direction: column; overflow: hidden; }
.mini-scroll-entidades { display: flex; flex-direction: column; gap: 6px; max-height: 180px; overflow-y: auto; margin-bottom: 10px; }
.item-personal-tienda { display: flex; align-items: center; gap: 8px; background: #111; padding: 6px; border-radius: 6px; border: 1px solid #222; }
.avatar-mini-p { font-size: 1.1rem; }
.item-personal-tienda h6 { margin: 0; font-size: 0.8rem; color: #fff; }
.item-personal-tienda small { color: #94a3b8; font-size: 0.7rem; }
.caja-mecanica-dados-comercio { background: #0c0c10; border: 1px dashed #334155; padding: 10px; border-radius: 8px; }
.btn-evaluar-dados { background: #b45309; border: none; color: white; padding: 8px 12px; border-radius: 6px; font-weight: bold; cursor: pointer; font-size: 0.85rem; flex: 1; }
.btn-util-comercio { background: #1e293b; border: none; color: #cbd5e1; padding: 4px 8px; border-radius: 4px; font-size: 0.75rem; cursor: pointer; font-weight: bold; }
.btn-util-comercio.rojo { background: #451a1a; color: #fca5a5; }

/* COL APARADOR */
.aparador-artculos-comercio { display: flex; flex-direction: column; overflow: hidden; }
.scroll-aparador-comercio { flex: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 6px; padding-right: 4px; }
.fila-articulo-dm-tienda { display: flex; align-items: center; padding: 8px 12px; border-radius: 6px; border: 1px solid #222; transition: 0.2s; }
.fila-articulo-dm-tienda.revelado { background: #0f172a; border-color: #1e3a8a; }
.fila-articulo-dm-tienda.oculto { background: #09090b; border-color: #18181b; opacity: 0.6; }
.btn-ojo-toggle { background: transparent; border: none; cursor: pointer; font-size: 1rem; padding: 0; }
.precio-cobre-tag { font-size: 0.9rem; margin-right: 15px; font-weight: bold; }
.btn-agregar-negociacion { background: #10b981; border: none; color: white; width: 26px; height: 26px; border-radius: 50%; font-weight: bold; cursor: pointer; font-size: 1.1rem; display: flex; align-items: center; justify-content: center; }
.btn-agregar-negociacion:disabled { background: #27272a; cursor: not-allowed; opacity: 0.5; }

/* MESA DE FACTURACIÓN */
.caja-carrito-vacía { text-align: center; color: #b45309; font-size: 0.85rem; background: rgba(180,83,9,0.04); padding: 20px; border-radius: 8px; border: 1px dashed #b45309; margin-top: 20px; }
.scroll-facturacion { flex: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 10px; padding: 5px 0; }
.tarjeta-factura-item { background: #09090c; border: 1px solid #232329; padding: 12px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.3); }
.btn-quitar-factura { background: transparent; border: none; color: #ef4444; cursor: pointer; font-size: 0.8rem; }
.input-group-comercio { display: flex; flex-direction: column; gap: 2px; }
.input-group-comercio label { font-size: 0.7rem; color: #94a3b8; font-weight: bold; }
.btn-cerrar-trato-dorado { background: #b45309; border: 1px solid #f59e0b; color: white; padding: 12px; font-family: 'Cinzel', serif; font-weight: bold; font-size: 1rem; border-radius: 8px; cursor: pointer; width: 100%; box-sizing: border-box; margin-top: 15px; box-shadow: 0 0 15px rgba(180,83,9,0.4); flex-shrink: 0; }
.btn-cerrar-trato-dorado:hover { background: #d97706; }

/* COMPONENTES DE AYUDA */
.flex-align { display: flex; align-items: center; }
.text-ellipsis { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.monospace { font-family: monospace; }
.margin-0 { margin: 0; }
.txt-gris { color: #94a3b8; }
.text-oro { color: #facc15; }
.txt-chico { font-size: 0.75rem; }
.text-xs { font-size: 0.7rem; }
.text-sm { font-size: 0.85rem; }
.text-lg { font-size: 1.1rem; }
.text-right { text-align: right; }
.font-bold { font-weight: bold; }
.border-bottom { border-bottom: 1px solid #1e293b; }
.pb-corto { padding-bottom: 5px; }
.mb-1 { margin-bottom: 10px; }
.mt-1 { margin-top: 10px; }
.mb-corto { margin-bottom: 5px; }
.mr-1 { margin-right: 5px; }
.ml-1 { margin-left: 5px; }
.w-40 { width: 40%; }
.w-50 { width: 50%; }
.w-60 { width: 60%; }
.w-full { width: 100%; }
.gap-1 { gap: 10px; }
.flex-center { display: flex; justify-content: center; align-items: center; }
.aviso-sin-personal, .aviso-vacio { text-align: center; font-size: 0.8rem; color: #52525b; padding: 15px 5px; }

.cuerpo-interactivo-comercial > *, .sub-grid-tienda-interna > * { min-width: 0; min-height: 0; }
@media (max-width: 1150px) {
  .hoja-registro-dm { width: 100%; height: 94dvh; max-width: 100%; }
  .cuerpo-interactivo-comercial { display: block; min-height: 0; overflow-y: auto; }
  .sub-grid-tienda-interna { grid-template-columns: minmax(185px,1fr) minmax(0,2fr); }
  .lista-tiendas-calles, .caja-facturacion-negociacion { border: 0; }
  .scroll-tiendas-comercio { max-height: 220px; }
  .interior-tienda-dm, .layout-interior-tienda { height: auto; overflow: visible; }
  .control-ciudades-bar, .header-comercio-activo, .fila-articulo-dm-tienda { flex-wrap: wrap; gap: 8px; }
}
@media (max-width: 630px) {
  .modal-tienda-dm-overlay { padding: 0; }
  .hoja-registro-dm { height: 100dvh; border-radius: 0; border-width: 0; }
  .control-ciudades-bar { padding: 8px 12px; }
  .control-ciudades-bar > * { max-width: 100%; min-width: 0; }
  .sub-grid-tienda-interna { display: block; }
  .entorno-comercial-dados { border: 0; padding: 0 0 12px; }
  .btn-agregar-negociacion { width: 36px; height: 36px; }
}
.total-trato { padding-block: .8rem; border-top: 1px solid #51402a; display: flex; justify-content: space-between; color: #ffe1a3; }
.aviso-sin-personal, .aviso-vacio { color: #a5adba; }
.btn-cerrar-tiendas { background: #19191e; border-color: #475569; }
@media (max-width: 630px) { .buscador-caja-tienda { order: 3; flex-basis: 100%; } .buscador-caja-tienda input { width: 100%; } }
</style>