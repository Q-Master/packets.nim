import std/macros
import internal/packet


macro packet*(head, body: untyped): untyped =
  let (packetname, basenames) = getNameAndBases(head)
  result = newStmtList()
  let (typeNode, requiredFields, exportedFields, allFields, baseFunctions) = createType(packetname, basenames, body)
  result.add(typeNode)
  result.add(baseFunctions)
  result.add(createNewInit(packetname))
  let deserData = createDeserData($packetname, exportedFields, allFields)
  result.add(deserData)
  result.add(genRequiredFieldsAmount(packetname, requiredFields.len))
  let serData = createSerData($packetname, exportedFields, allFields, requiredFields)
  result.add(serData)
  echo result.repr


macro arrayPacket*(head, body: untyped): untyped =
  let (packetname, basenames) = getNameAndBases(head)
  result = newStmtList()
  let (typeNode, requiredFields, exportedFields, allFields, baseFunctions) = createType(packetname, basenames, body, true)
  result.add(typeNode)
  result.add(baseFunctions)
  result.add(createNewInit(packetname))
  let deserData = createArrayDeserData($packetname, exportedFields, allFields)
  result.add(deserData)
  result.add(genRequiredFieldsAmount(packetname, requiredFields.len))
  let serData = createArraySerData($packetname, exportedFields, allFields)
  result.add(serData)
