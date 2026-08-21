import std/macros
import internal/packet


macro packet*(head, body: untyped): untyped =
  let (packetname, basenames, needId) = getNameAndBases(head)
  result = newStmtList()
  let (typeNode, baseFunctions) = createType(packetname, basenames, body, needId)
  result.add(typeNode)
  result.add(baseFunctions)
  result.add(createNewInit(packetname, needId))
  let deserData = createDeserData($packetname, needId)
  result.add(deserData)
  result.add(genRequiredFieldsAmount(packetname))
  let serData = createSerData($packetname, needId)
  result.add(serData)


macro arrayPacket*(head, body: untyped): untyped =
  let (packetname, basenames, needId) = getNameAndBases(head)
  result = newStmtList()
  let (typeNode, baseFunctions) = createType(packetname, basenames, body, needId, true)
  result.add(typeNode)
  result.add(baseFunctions)
  result.add(createNewInit(packetname, needId))
  let deserData = createArrayDeserData($packetname, needId)
  result.add(deserData)
  result.add(genRequiredFieldsAmount(packetname))
  let serData = createArraySerData($packetname, needId)
  result.add(serData)
