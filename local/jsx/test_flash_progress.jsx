class Interaction extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      atProgress: []
    };
  }

  handleButtonCancel = () => {
    const tMsg = {
      button: 'cancel'
    };
    fnSend(tMsg);
  };

  onInteractionData = (strData) => {
    let tJson = null;
    try {
      tJson = JSON.parse(strData);
    } catch(error) {
      console.error("Received malformed JSON:", error, strData);
    }

    if( tJson!==null ) {
      let atProgressNew = []
      tJson.forEach(function(tData) {
        let tAttr = {
          display: tData.display,
          size: tData.size,
          pos_erase: tData.pos_erase,
          pos_flash: tData.pos_flash
        };
        atProgressNew.push(tAttr);
      }, this);

      this.setState({
        atProgress: atProgressNew
      });
    }
  }

  render() {
    let atElements = [];
    this.state.atProgress.forEach(function(tData, uiIndex) {
      console.debug(tData);
      const strKey = "Progress" + uiIndex.toString();

      let tProgress;
      const uiTotal = tData.size;
      if( uiTotal==0 ) {
        tProgress = (<LinearProgress key={strKey+"progress"} variant="indeterminate" />);
      } else {
        const uiErase = (tData.pos_erase * 100) / uiTotal;
        const uiFlash = (tData.pos_flash * 100) / uiTotal;
        tProgress = (<LinearProgress key={strKey+"progress"} variant="buffer" value={uiFlash} valueBuffer={uiErase} />);
      }

      atElements.push(<div key={strKey+"div1"} style={{display: 'block', margin: '1em'}}><Typography variant="body1">{tData.display} | Erase = {(tData.pos_erase * 100) / uiTotal}% | Flash = {(tData.pos_flash * 100) / uiTotal}%</Typography>{tProgress}</div>);
    }, this);

    return (
      <div>
        <div style={{width: '100%'}}>
          <Typography align="center" variant="h2" gutterBottom>Flashing...</Typography>
          <Typography align="center" variant="h4" gutterBottom>Zeigt noch Mist an, aber solange es sich bewegt, lebt es.</Typography>
          <Typography align="center" variant="h4" gutterBottom>Test Ladebalken v3</Typography>
        </div>

        <div>{atElements}</div>

        <div style={{width: '100%', textAlign: 'center', verticalAlign: 'middle', padding: '2em'}}>
          <div style={{display: 'inline', paddingLeft: '2em', paddingRight: '2em'}}>
            <Button color="secondary" variant="contained" onClick={this.handleButtonCancel}>
              <SvgIcon>
                <path d="M0 0h24v24H0z" fill="none"/><path d="M14.59 8L12 10.59 9.41 8 8 9.41 10.59 12 8 14.59 9.41 16 12 13.41 14.59 16 16 14.59 13.41 12 16 9.41 14.59 8zM12 2C6.47 2 2 6.47 2 12s4.47 10 10 10 10-4.47 10-10S17.53 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/>
              </SvgIcon>
              Abbrechen
            </Button>
          </div>
        </div>
      </div>
    );
  }
}
