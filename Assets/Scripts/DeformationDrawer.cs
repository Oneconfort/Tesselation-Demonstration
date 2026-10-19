using UnityEngine;
using UnityEngine.UIElements;

public class DeformationDrawer : MonoBehaviour
{
    public ComputeShader defCompute;
    public RenderTexture planeRT;
    Vector3 myPos;
    bool isMoving;
    private string imageP = "image";
    private string colorValP = "colorValue";
    private string resolutionP = "resolution";
    private string posXP = "posX";
    private string posYP = "posY";
    private string  spotSizeP = "spotSize";
    private string drawSpotKernel = "DrawnSpot";
    private string scaleP = "scale";
    private string smoothnessP = "smoothness";


    private Vector2Int pos = new Vector2Int(256, 256);
    public float spotSize = 5;
    public float smoothness;

    private DeformationControl defControl;
    private GameObject[] deformObjects;

    private int deformLayer = 1 << 3;
    void Awake()
    {
        deformObjects = GameObject.FindGameObjectsWithTag("Deformation");
        myPos = transform.position;
        isMoving = false;
    }

    void Start()
    {
        DrawnSpot();
    }
    void FixedUpdate()
    {
        if(isMoving)
        {
            
            DrawnSpot();
        }
    }

    void LateUpdate()
    {
        if(myPos != transform.position)
        {
            isMoving = true;
            myPos = transform.position;
        }
        else
        {
            isMoving = false;
        }
    }

    void DrawnSpot()
    {
        RaycastHit hit;
        if(Physics.Raycast(transform.position, Vector3.down, out hit ,50, deformLayer))
        {
            defControl = hit.transform.GetComponent<DeformationControl>();
            planeRT = defControl.planeRT;
            GetCoordenate();
            DispatchDrawn();
         }   
    }
    void GetCoordenate()
    {
        RaycastHit hit;

        if(Physics.Raycast(transform.position, Vector3.down, out hit, 50, deformLayer))
        {
            float scale = defControl.transform.localScale.x;
            Vector2 pixelUV = hit.textureCoord;
            pixelUV.x *= planeRT.width;
            pixelUV.y *= planeRT.height;
            Debug.DrawRay(transform.position, Vector3.down * hit.distance, Color.yellow);
            pos = new Vector2Int ((int)pixelUV.x, (int)pixelUV.y);
        }
        
    }
    void DispatchDrawn()
    {

        if(planeRT == null) return;
        if (defCompute == null) return;
        
        float scale = defControl.transform.localScale.x;

        int kernelHandle = defCompute.FindKernel(drawSpotKernel);
        defCompute.SetTexture(kernelHandle, imageP, planeRT);
        defCompute.SetFloat(colorValP, 0);
        defCompute.SetFloat(resolutionP, planeRT.width);
        defCompute.SetFloat(posXP, pos.x);
        defCompute.SetFloat(posYP, pos.y);
        defCompute.SetFloat(spotSizeP, spotSize);
        defCompute.SetFloat(scaleP, scale);
        defCompute.SetFloat(smoothnessP, smoothness);

        defCompute.Dispatch(kernelHandle, planeRT.width / 8, planeRT.height / 8, 1);
    }
}
