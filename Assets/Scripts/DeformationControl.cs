using UnityEngine;

public class DeformationControl : MonoBehaviour
{
    public ComputeShader defCompute;
    public RenderTexture planeRT;
    public float colorVal;
    public int resolution = 512;
    public bool showDrawn = false;
    private string imageP = "image";
    private string colorValP = "colorValue";
    private string resolutionP = "resolution";
    private string posXP = "posX";
    private string posYP = "posY";
    private string  spotSizeP = "spotSize";
    private string scaleP = "scale";
    private string smoothnessP = "smoothness";
    private string fillWhiteKernel = "FillWhite";
    private string csMainKernel = "CSMain";
    
    private MeshRenderer meshRenderer;

    void Awake()
    {
        CreateRenderTexture();
        SetTextureWhite();
        SetMaterialTexture();
        InvokeRepeating(nameof(AddLayer), 0.1f, 0.1f);
        ExtentBounds();
    }

    void CreateRenderTexture()
    {
        planeRT = new RenderTexture(resolution, resolution, 24);
        planeRT.enableRandomWrite = true;
        planeRT.Create();
    }

    void SetTextureWhite()
    {
        int kernelHandle = defCompute.FindKernel(fillWhiteKernel);
        defCompute.SetTexture(kernelHandle, imageP, planeRT);
        defCompute.SetFloat(colorValP, colorVal);
        defCompute.SetFloat(resolutionP, resolution);
        defCompute.SetFloat(posXP, 0);
        defCompute.SetFloat(posYP, 0);
        defCompute.SetFloat(spotSizeP, 0);
        defCompute.SetFloat(scaleP, 0);
        defCompute.SetFloat(smoothnessP, 0);

        defCompute.Dispatch(kernelHandle, planeRT.width / 8, planeRT.height / 8, 1);
    }

    void SetMaterialTexture()
    {
        meshRenderer = GetComponent<MeshRenderer>();
        if (showDrawn)
        {   
            meshRenderer.material.SetTexture("_BaseMap", planeRT);  
        }
        else
        {
            meshRenderer.material.SetTexture("_DeformationMap", planeRT);
        }
        
    }
    void AddLayer()
    {
        int kernelHandle = defCompute.FindKernel(csMainKernel);
        defCompute.SetTexture(kernelHandle, imageP, planeRT);
        defCompute.SetFloat(colorValP, colorVal);
        defCompute.SetFloat(resolutionP, resolution);
        defCompute.SetFloat(posXP, 0);
        defCompute.SetFloat(posYP, 0);
        defCompute.SetFloat(spotSizeP, 0);
        defCompute.SetFloat(scaleP, 0);
        defCompute.SetFloat(smoothnessP, 0);


        defCompute.Dispatch(kernelHandle, planeRT.width / 8, planeRT.height / 8, 1);
    }

    void ExtentBounds()
    {
        Bounds bounds = GetComponent<MeshFilter>().mesh.bounds;
        bounds.extents = new Vector3 (2,0,2);
        GetComponent<MeshFilter>().mesh.bounds = bounds;
    }
}
