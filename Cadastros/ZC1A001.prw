#Include "TOTVS.CH"
#Include "FWMVCDef.ch"

// Cadastro da ZC1 - qual conta da IntegrationPlatform atende cada finalidade
// de integracao.
User Function ZC1A001()
    Local oBrowse := FWMBrowse():New()

    oBrowse:SetAlias("ZC1")
    oBrowse:SetDescription("Referencia de Conector por Finalidade")
    oBrowse:AddLegend("ZC1_ATIVO == 'S'", "GREEN", "Ativa")
    oBrowse:AddLegend("ZC1_ATIVO == 'N'", "RED",   "Inativa")
    oBrowse:Activate()
Return Nil

Static Function MenuDef()
    Local aRotina := {}

    ADD OPTION aRotina TITLE "Visualizar" ACTION "VIEWDEF.ZC1A001" OPERATION MODEL_OPERATION_VIEW   ACCESS 0
    ADD OPTION aRotina TITLE "Incluir"    ACTION "VIEWDEF.ZC1A001" OPERATION MODEL_OPERATION_INSERT ACCESS 0
    ADD OPTION aRotina TITLE "Alterar"    ACTION "VIEWDEF.ZC1A001" OPERATION MODEL_OPERATION_UPDATE ACCESS 0
    ADD OPTION aRotina TITLE "Excluir"    ACTION "VIEWDEF.ZC1A001" OPERATION MODEL_OPERATION_DELETE ACCESS 0
Return aRotina

Static Function ModelDef()
    Local oModel := Nil
    Local oStZC1 := FWFormStruct(1, "ZC1")

    oModel := MPFormModel():New("ZC1A001M", , {|oMdl| ValidPos(oMdl)})
    oModel:SetDescription("Referencia de Conector por Finalidade")

    oModel:AddFields("ZC1MASTER", , oStZC1)
    oModel:SetPrimaryKey({"ZC1_FILIAL", "ZC1_CODIGO"})
    oModel:GetModel("ZC1MASTER"):SetDescription("Finalidade")
Return oModel

Static Function ViewDef()
    Local oView   := Nil
    Local oModel  := FWLoadModel("ZC1A001")
    Local oStZC1  := FWFormStruct(2, "ZC1")

    oView := FWFormView():New()
    oView:SetModel(oModel)

    oView:AddField("VIEW_ZC1", oStZC1, "ZC1MASTER")
    oView:CreateHorizontalBox("TELA", 100)
    oView:SetOwnerView("VIEW_ZC1", "TELA")
    oView:EnableTitleView("VIEW_ZC1", "Finalidade de Integracao")
Return oView

Static Function ValidPos(oModel)
    Local oZC1    := oModel:GetModel("ZC1MASTER")
    Local cCodigo := AllTrim(oZC1:GetValue("ZC1_CODIGO"))
    Local cCateg  := AllTrim(oZC1:GetValue("ZC1_CATEG"))
    Local lRet    := .T.

    If cCodigo != Lower(cCodigo)
        Help(, , "ZC1A001", , "Codigo da finalidade deve ser minusculo", 1, 0, , , , , , ;
             {"Use o mesmo identificador da IntegrationPlatform, por exemplo cobranca-whatsapp"})
        lRet := .F.
    ElseIf cCateg != Lower(cCateg)
        Help(, , "ZC1A001", , "Categoria deve ser minuscula", 1, 0, , , , , , ;
             {"Use o mesmo identificador da IntegrationPlatform, por exemplo whatsapp"})
        lRet := .F.
    EndIf
Return lRet
