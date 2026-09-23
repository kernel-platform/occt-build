// smoke.cc — exercises a staged OCCT build end to end: modelling + booleans,
// shape healing, an XCAF document with names written to STEP and read back, a
// BinXCAF save/reopen, and BRepMesh tessellation. Exits non-zero on any failure.

#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Tool.hxx>
#include <BinXCAFDrivers.hxx>
#include <Poly_Triangulation.hxx>
#include <STEPCAFControl_Reader.hxx>
#include <STEPCAFControl_Writer.hxx>
#include <ShapeFix_Shape.hxx>
#include <Standard_Version.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDataStd_Name.hxx>
#include <TDocStd_Document.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <TopoDS.hxx>
#include <XCAFApp_Application.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <gp_Ax2.hxx>

#include <cstdio>
#include <string>

static int Fail(const char* what) {
  std::fprintf(stderr, "smoke: FAIL: %s\n", what);
  return 1;
}

int main(int argc, char** argv) {
  const std::string dir = argc > 1 ? argv[1] : ".";
  const std::string step_path = dir + "/smoke.step";
  const std::string xbf_path = dir + "/smoke.xbf";

  TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(5, 5, 5), gp::DZ()), 3.0, 12.0).Shape();
  BRepAlgoAPI_Fuse fuse(box, cyl);
  if (!fuse.IsDone()) return Fail("boolean fuse");
  Handle(ShapeFix_Shape) fix = new ShapeFix_Shape(fuse.Shape());
  fix->Perform();
  const TopoDS_Shape part = fix->Shape();

  Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
  BinXCAFDrivers::DefineFormat(app);
  Handle(TDocStd_Document) doc;
  app->NewDocument("BinXCAF", doc);
  Handle(XCAFDoc_ShapeTool) shapes = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
  const TDF_Label label = shapes->AddShape(part);
  TDataStd_Name::Set(label, "smoke_part");

  STEPCAFControl_Writer writer;
  writer.SetNameMode(true);
  if (!writer.Transfer(doc, STEPControl_AsIs)) return Fail("STEP transfer");
  if (writer.Write(step_path.c_str()) != IFSelect_RetDone) return Fail("STEP write");

  Handle(TDocStd_Document) read_doc;
  app->NewDocument("BinXCAF", read_doc);
  STEPCAFControl_Reader reader;
  reader.SetNameMode(true);
  if (reader.ReadFile(step_path.c_str()) != IFSelect_RetDone) return Fail("STEP read");
  if (!reader.Transfer(read_doc)) return Fail("STEP read transfer");

  if (app->SaveAs(read_doc, TCollection_ExtendedString(xbf_path.c_str())) != PCDM_SS_OK)
    return Fail("BinXCAF save");
  app->Close(read_doc);
  Handle(TDocStd_Document) cached;
  if (app->Open(TCollection_ExtendedString(xbf_path.c_str()), cached) != PCDM_RS_OK)
    return Fail("BinXCAF open");

  TDF_LabelSequence roots;
  XCAFDoc_DocumentTool::ShapeTool(cached->Main())->GetFreeShapes(roots);
  if (roots.Length() != 1) return Fail("expected one free shape after the round trip");
  Handle(TDataStd_Name) name;
  if (!roots.Value(1).FindAttribute(TDataStd_Name::GetID(), name) ||
      TCollection_AsciiString(name->Get()) != "smoke_part")
    return Fail("part name lost in STEP/BinXCAF round trip");
  const TopoDS_Shape shape = XCAFDoc_ShapeTool::GetShape(roots.Value(1));

  BRepMesh_IncrementalMesh mesh(shape, 0.1, false, 0.5, true);
  int faces = 0, triangles = 0;
  for (TopExp_Explorer ex(shape, TopAbs_FACE); ex.More(); ex.Next()) {
    ++faces;
    TopLoc_Location loc;
    Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(TopoDS::Face(ex.Current()), loc);
    if (tri.IsNull()) return Fail("face without triangulation");
    triangles += tri->NbTriangles();
  }
  if (faces == 0 || triangles == 0) return Fail("empty tessellation");
  app->Close(cached);

  std::printf("{\"occt\": \"%s\", \"faces\": %d, \"triangles\": %d}\n", OCC_VERSION_STRING_EXT,
              faces, triangles);
  return 0;
}
